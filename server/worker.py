"""One durable authoring worker; never automatically retries a paid operation."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import time

from tools.forge import jobs
from tools.forge.hosted_accounting import SqliteAccounting
from tools.forge.provider import ForgeError, OpenAIProvider
from .service import ForgeService, correction_files, safe_file, setting_label
from .store import ServiceError, Store


def configuration() -> dict:
    # Only this worker can mount the optional private secret volume. Do not
    # inspect a checkout .env or expose raw parser/errors to the API.
    secret = {}
    file = os.environ.get("FORGE_SECRET_FILE")
    if file:
        path = Path(file)
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 16384:
            raise ServiceError("The worker's private provider configuration is unavailable.")
        try:
            from dotenv import dotenv_values
            secret = dotenv_values(path)
        except Exception:
            raise ServiceError("The worker's private provider configuration could not be read.") from None
    return {"key": secret.get("OPENAI_API_KEY", os.environ.get("OPENAI_API_KEY", "")),
            "model": secret.get("OPENAI_IMAGE_MODEL", secret.get("IMAGE_MODEL", os.environ.get("OPENAI_IMAGE_MODEL", os.environ.get("IMAGE_MODEL", "gpt-image-1-mini")))),
            "quality": secret.get("OPENAI_IMAGE_QUALITY", secret.get("QUALITY", os.environ.get("OPENAI_IMAGE_QUALITY", os.environ.get("QUALITY", "low")))),
            "analysis_model": "gpt-6-luna"}


def heartbeat(store: Store, config: dict):
    jobs.write_json(store.root / "worker.json", {"ready": True,
                    "key_present": bool(config.get("key")), "updated_at": time.time(),
                    "analysis_model": setting_label(config.get("analysis_model"), config.get("key")),
                    "image_model": setting_label(config.get("model"), config.get("key")),
                    "image_quality": setting_label(config.get("quality"), config.get("key"))})


class OwnedProvider:
    """Re-check revocation at each dispatch, including between both images."""
    def __init__(self, store: Store, owner: str, path: Path, provider):
        self.store, self.owner, self.path, self.provider = store, owner, path, provider

    def check(self):
        jobs.check_cancel(self.path.parent)
        if not self.store.active_invite(self.owner):
            raise jobs.Cancelled

    def analyse(self, *args):
        self.check()
        return self.provider.analyse(*args)

    def image(self, *args):
        self.check()
        return self.provider.image(*args)


def apply_operation(store: Store, operation: dict):
    owner, identity = operation["owner_id"], operation["job_id"]
    path = store.require_job(owner, identity)
    payload = json.loads(operation["payload"])
    job = jobs.read_json(path, 32000)
    if "proposal" in payload:
        from tools.forge.provider import validate_proposal
        proposal = validate_proposal(payload["proposal"])
        job["proposal"] = proposal
        if operation["command"] == "generate":
            job["preferred_name"] = proposal["name"]
        jobs.write_json(path, job)
        jobs.write_json(path.parent / "proposal.json", proposal)
    edits = correction_files(payload.get("files", {}))
    if "rig_edits.json" in edits or any(name.startswith("masks/") for name in edits):
        # Rig corrections need the server's verified editable inputs, never
        # client-supplied rigs, scripts or filenames.
        with store.connect() as db:
            parent = db.execute("SELECT parent_job_id FROM jobs WHERE job_id=? AND owner_id=?", (identity, owner)).fetchone()
        if parent and parent[0] and not (path.parent / "rig.json").exists():
            original = store.require_job(owner, parent[0]).parent
            for file in original.rglob("*"):
                relative = file.relative_to(original).as_posix()
                editable = relative in jobs.EDITABLE_FILES or relative.startswith("parts/") or relative.startswith("masks/")
                if editable and safe_file(relative) and file.is_file():
                    jobs.atomic_bytes(path.parent / relative, jobs.read_bytes(file, 20 * 1024 * 1024))
    for relative, data in edits.items():
        jobs.atomic_bytes(path.parent / relative, data)
    jobs.write_json(path.parent / "status.json", {"state": "queued", "message": "Starting " + operation["command"] + "."})


def run_once(store: Store, *, config: dict | None = None, provider=None,
             converter=None, baker=None) -> bool:
    config = configuration() if config is None else config
    heartbeat(store, config)
    operation = store.claim()
    if operation is None:
        return False
    service = ForgeService(store)
    try:
        if not store.active_invite(operation["owner_id"]):
            store.finish(operation["operation_id"], "cancelled", "Invitation revoked.")
            return True
        apply_operation(store, operation)
        path = store.require_job(operation["owner_id"], operation["job_id"])
        owned_provider = provider
        if operation["command"] != "bake" and (provider is not None or config.get("key")):
            owned_provider = OwnedProvider(store, operation["owner_id"], path,
                                           provider if provider is not None else OpenAIProvider(config))
        result = jobs.run_job(operation["command"], path, root=store.root,
                              provider=owned_provider, converter=converter, baker=baker,
                              config=config,
                              accounting=SqliteAccounting(store.db_path, operation["owner_id"]))
        store.finish(operation["operation_id"], result["state"], service.safe_message(result.get("message")))
    except (ForgeError, ServiceError) as error:
        store.finish(operation["operation_id"], "failed", service.safe_message(str(error)))
    except Exception:
        # No raw exception text: SDK errors can include private requests.
        store.finish(operation["operation_id"], "failed", "Authoring failed. Existing fighters and request history were preserved.")
    finally:
        heartbeat(store, config)
    return True


@contextmanager
def exclusive_worker(store: Store):
    path = store.root / ".hosted-worker.lock"
    descriptor = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "a+") as stream:
        try:
            fcntl.flock(stream, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ServiceError("Another hosted forge worker already owns this storage.", 409) from None
        yield


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", default=os.environ.get("FORGE_DATA_ROOT", "/data/forge"))
    parser.add_argument("--once", action="store_true", help="Process at most one queued operation")
    args = parser.parse_args(argv)
    store = Store(args.data_root)
    with exclusive_worker(store):
        store.recover_interrupted()
        config = configuration()
        while True:
            worked = run_once(store, config=config)
            if args.once:
                return 0
            if not worked:
                time.sleep(1)


if __name__ == "__main__":
    raise SystemExit(main())
