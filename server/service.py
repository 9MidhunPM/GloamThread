"""Bounded browser protocol around the existing, non-executable forge formats."""
from __future__ import annotations

import base64
import binascii
import io
import json
from pathlib import Path
import re
import secrets
import shutil
import time

from PIL import Image

from tools.forge.art import RIG_PARTS
from tools.forge.hosted_accounting import SqliteAccounting
from tools.forge.jobs import (EDITABLE_FILES, RESERVATIONS, ForgeError, atomic_bytes, read_bytes,
                              read_json, snapshot_source, validate_candidate, write_json)
from tools.forge.provider import validate_proposal
from .store import ServiceError, Store

MAX_BODY_BYTES = 48 * 1024 * 1024
MAX_FILE_BYTES = 20 * 1024 * 1024
MAX_SNAPSHOT_BYTES = 64 * 1024 * 1024
REQUEST_ESTIMATES = {"analyse_usd": RESERVATIONS["analyse"] / 1000000,
                     "generate_usd": (RESERVATIONS["parts"] + RESERVATIONS["theme"]) / 1000000,
                     "bake_usd": 0}
BUNDLE_FILES = {"manifest.json", "character.png", "portrait.png", "background.png", "materials.png", "provenance.json"}
PART_IDS = set().union(*RIG_PARTS.values()) | {"master"}
FIXED_FILES = {"source.png", "proposal.json", "provenance.json", "rig.json", "rig_edits.json",
               "source_layout.json", "illustrated_master.png", "master.png", "theme_background.png",
               "theme_materials.png", "source_provenance.json", "creator_generation.json",
               "raw/source.png", "raw/parts.png", "raw/theme.png", "raw/proposal.json"}
CLONE_FILES = {"source.png", "proposal.json", "provenance.json", "source_layout.json", "illustrated_master.png",
               "creator_generation.json", "raw/source.png", "raw/parts.png", "raw/theme.png", "raw/proposal.json"}


def setting_label(value: object, key: object = None) -> str:
    """Expose model labels, with no path/control data or misplaced credential."""
    if (not isinstance(value, str) or value == key or value.startswith("sk-")
            or re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.:-]{0,79}", value) is None):
        return "unavailable"
    return value


def safe_file(name: str) -> bool:
    if name in FIXED_FILES:
        return True
    path = name.split("/")
    if len(path) != 2:
        return False
    if path[0] in {"parts", "masks"}:
        return path[1].endswith(".png") and path[1][:-4] in PART_IDS
    return re.fullmatch(r"candidate(?:-bake-[0-9]+)?", path[0]) is not None and path[1] in BUNDLE_FILES


def decode_file(value: object, maximum: int = MAX_FILE_BYTES) -> bytes:
    if not isinstance(value, str) or len(value) > (maximum + 2) // 3 * 4:
        raise ServiceError("Uploaded file is missing or exceeds its byte limit.")
    try:
        data = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error):
        raise ServiceError("Uploaded file must use valid base64 encoding.") from None
    if not data or len(data) > maximum:
        raise ServiceError("Uploaded file is empty or exceeds its byte limit.")
    return data


def parse_json(data: bytes) -> dict:
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate key")
            result[key] = value
        return result
    def constant(_):
        raise ValueError("non-finite number")
    try:
        value = json.loads(data, object_pairs_hook=pairs, parse_constant=constant)
        if not isinstance(value, dict):
            raise ValueError
        return value
    except (ValueError, UnicodeError):
        raise ServiceError("Expected one valid JSON object with unique fields.") from None


def png(data: bytes, maximum: int, *, minimum: int = 1):
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.format != "PNG" or getattr(image, "n_frames", 1) != 1 or not all(minimum <= extent <= maximum for extent in image.size):
                raise ValueError
            image.load()
    except (OSError, ValueError, Image.DecompressionBombError):
        raise ServiceError("Upload must be one PNG within the supported pixel bounds.") from None


def correction_files(value: object) -> dict[str, bytes]:
    if not isinstance(value, dict) or len(value) > 32:
        raise ServiceError("Correction files must be a bounded file map.")
    files = {}
    total = 0
    for name, encoded in value.items():
        allowed = name in {"source_layout.json", "rig_edits.json", "illustrated_master.png"}
        allowed = allowed or (isinstance(name, str) and name.startswith("masks/") and safe_file(name))
        if not allowed:
            raise ServiceError("Only crop, rig, mask and illustrated-master corrections may be uploaded.")
        data = decode_file(encoded, 64 * 1024 if name.endswith(".json") else 8 * 1024 * 1024)
        total += len(data)
        if total > 24 * 1024 * 1024:
            raise ServiceError("Correction files exceed the combined byte limit.")
        if name.endswith(".json"):
            parse_json(data)
        else:
            png(data, 2048, minimum=32 if name == "illustrated_master.png" else 1)
        files[name] = data
    return files


class ForgeService:
    def __init__(self, store: Store):
        self.store = store

    def accounting(self, owner: str) -> SqliteAccounting:
        return SqliteAccounting(self.store.db_path, owner)

    def configuration(self, owner: str | None) -> dict:
        worker = self.store.root / "worker.json"
        state = {}
        if worker.is_file() and not worker.is_symlink() and time.time() - worker.stat().st_mtime < 600:
            state = read_json(worker, 4096)
        analysis = setting_label(state.get("analysis_model"))
        image = setting_label(state.get("image_model"))
        quality = setting_label(state.get("image_quality"))
        return {"ok": True, "authenticated": owner is not None,
                "worker_ready": bool(state.get("ready")), "key_present": bool(state.get("key_present")),
                "analysis_model": analysis, "image_model": image, "image_quality": quality,
                "models": {"analysis": analysis, "image": image, "quality": quality},
                "request_estimates": REQUEST_ESTIMATES,
                "budget": self.accounting(owner).status(required=RESERVATIONS["analyse"]) if owner else {
                    "limits_enabled": False, "required_usd": RESERVATIONS["analyse"] / 1000000}}

    def create_job(self, owner: str, payload: dict) -> dict:
        allowed = {"source_png", "description", "preferred_name", "art_mode", "parent_job_id"}
        if set(payload) - allowed:
            raise ServiceError("Job contains unsupported fields.")
        description = payload.get("description", "")
        name = payload.get("preferred_name", "")
        mode = payload.get("art_mode", "illustrated-master-v1")
        if not isinstance(description, str) or len(description) > 2000:
            raise ServiceError("Description must contain at most 2,000 characters.")
        if not isinstance(name, str) or len(name) > 40 or any(ord(c) < 32 for c in name):
            raise ServiceError("Name must contain at most 40 printable characters.")
        if not isinstance(mode, str) or mode not in {"", "illustrated-master-v1"}:
            raise ServiceError("Unsupported character art mode.")
        parent = payload.get("parent_job_id")
        old = None
        if parent is not None:
            old = self.store.require_job(owner, parent)
            operation = self.store.latest_operation(owner, parent)
            if operation and operation["state"] in {"queued", "running"}:
                raise ServiceError("Wait for the retained artwork to finish before correcting it.", 409)
        source = decode_file(payload["source_png"]) if "source_png" in payload else (read_bytes(old.parent / "source.png", MAX_FILE_BYTES) if old else None)
        if source is None:
            raise ServiceError("Draw or import a source PNG first.")
        png(source, 4096)
        identity = secrets.token_hex(16)
        path = self.store.job_path(owner, identity)
        path.parent.mkdir(parents=True, mode=0o700)
        try:
            if old:
                parent_job = read_json(old, 32000)
                # Corrections retain the exact generation identity and immutable pixels.
                if source != read_bytes(old.parent / "source.png", MAX_FILE_BYTES):
                    raise ServiceError("Corrections must retain their original source drawing.")
                job = {k: v for k, v in parent_job.items() if k in {"schema_version", "description", "preferred_name", "art_mode", "proposal"}}
                for item in CLONE_FILES:
                    original = old.parent / item
                    if original.exists():
                        atomic_bytes(path.parent / item, read_bytes(original, MAX_FILE_BYTES))
            else:
                job = {"schema_version": 1, "description": description.strip(), "art_mode": mode}
                if name.strip():
                    job["preferred_name"] = name.strip()
            atomic_bytes(path.parent / "source.png", source)
            job["source_image"] = str(path.parent / "source.png")
            write_json(path, job)
            snapshot_source(job, path.parent)  # Image/visible-pixel preflight, no SDK or reservation.
            self.store.record_job(owner, identity, parent)
        except BaseException:
            shutil.rmtree(path.parent)
            raise
        return {"ok": True, "job_id": identity}

    def enqueue(self, owner: str, identity: str, payload: dict) -> dict:
        path = self.store.require_job(owner, identity)
        if set(payload) - {"command", "idempotency_key", "proposal", "files"}:
            raise ServiceError("Operation contains unsupported fields.")
        command = payload.get("command")
        if not isinstance(command, str) or command not in {"analyse", "generate", "bake"}:
            raise ServiceError("Unsupported authoring operation.")
        if "proposal" in payload:
            validate_proposal(payload["proposal"])
        if command == "generate" and "proposal" not in payload:
            raise ServiceError("Review and approve a proposal before generation.")
        files = correction_files(payload.get("files", {}))
        if files and command != "bake":
            raise ServiceError("Corrections are accepted only by Convert saved artwork.")
        # Accepting the operation is durable before the worker changes any files.
        result = self.store.enqueue(owner, identity, command, payload.get("idempotency_key"), payload)
        if result["reused"]:
            return result
        if (path.parent / "cancel").exists():
            self.store.finish(result["operation_id"], "cancelled", "This draft is cancelled or interrupted. Create a new attempt.")
        else:
            write_json(path.parent / "status.json", {"state": "queued", "message": "Queued for " + command + "."})
        return result

    def status(self, owner: str, identity: str) -> dict:
        path = self.store.require_job(owner, identity)
        status_path = path.parent / "status.json"
        raw = read_json(status_path, 64000) if status_path.is_file() else {}
        operation = self.store.latest_operation(owner, identity)
        state = operation["state"] if operation else "draft"
        message = operation["message"] if operation else "Drawing retained. Choose Analyse or approve your design."
        if operation and raw and (state == "running" or raw.get("state") == state):
            state = raw.get("state", state)
            message = raw.get("message", message)
        # Project the prospective stage estimate without copying the worker's
        # global accounting totals. A retained correction is SDK-free.
        required = 0
        if state == "awaiting_approval":
            required = RESERVATIONS["parts"] + RESERVATIONS["theme"]
        elif state == "draft" and not (path.parent / "provenance.json").exists():
            required = RESERVATIONS["analyse"]
        budget = self.accounting(owner).status(path, required=required)
        job = read_json(path, 32000)
        result = {"ok": True, "job_id": identity, "state": state,
                  "message": self.safe_message(message), "estimated_usd": budget["job_reserved_usd"],
                  "reserved_usd": budget["job_reserved_usd"], "budget": budget,
                  "request_estimates": REQUEST_ESTIMATES,
                  "candidate_ready": False, "candidate_dir": "",
                  "description": job.get("description", ""),
                  "preferred_name": job.get("preferred_name", ""),
                  "art_mode": job.get("art_mode", ""),
                  "operation_id": operation["operation_id"] if operation else ""}
        proposal_path = path.parent / "proposal.json"
        if proposal_path.is_file():
            result["proposal"] = validate_proposal(read_json(proposal_path, 32000))
        candidate = path.parent / "candidate"
        if candidate.exists() and state == "complete":
            validate_candidate(candidate)
            result.update(candidate_ready=True, candidate_dir="candidate")
        if isinstance(raw.get("code"), str):
            result["code"] = raw["code"][:80]
        result["retry_allowed"] = False
        return result

    def safe_message(self, message: object) -> str:
        if not isinstance(message, str):
            return "Authoring status unavailable."
        # Native worker errors may name its .env path. Never expose server paths.
        text = message.replace(str(self.store.root), "[private authoring storage]")
        text = re.sub(r"(?:/[A-Za-z0-9_.-]+){2,}", "[private authoring path]", text)
        return text[:1000]

    def snapshot(self, owner: str, identity: str) -> dict:
        path = self.store.require_job(owner, identity)
        operation = self.store.latest_operation(owner, identity)
        if operation and operation["state"] in {"queued", "running"}:
            raise ServiceError("Artwork is still changing; wait for the operation to finish.", 409)
        files = {}
        total = 0
        for file in sorted(path.parent.rglob("*")):
            relative = file.relative_to(path.parent).as_posix()
            if not safe_file(relative):
                continue
            if file.is_symlink() or not file.is_file() or file.resolve() != file:
                raise ServiceError("Retained artwork contains an unsafe file.", 409)
            data = read_bytes(file, MAX_FILE_BYTES)
            total += len(data)
            if total > MAX_SNAPSHOT_BYTES:
                raise ServiceError("Retained artwork exceeds the download limit.", 409)
            files[relative] = base64.b64encode(data).decode("ascii")
        candidate = "candidate" if "candidate/manifest.json" in files else ""
        if candidate:
            validate_candidate(path.parent / candidate)
        return {"ok": True, "files": files, "candidate_dir": candidate}
