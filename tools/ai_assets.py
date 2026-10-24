#!/usr/bin/env python3
"""Generate original side-view art with OpenAI; keep provider calls outside Godot."""
from __future__ import annotations

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import re
import sys
import uuid

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MODELS = {"gpt-image-1-mini", "gpt-image-2", "gpt-image-2.5-flare", "gpt-image-2.5-sunburst"}
MAX_IMAGE_BYTES = 25 * 1024 * 1024


class AuthoringError(Exception):
    """A message safe to display without provider bodies or credentials."""


def now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def write_json(path: Path, value: dict) -> None:
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def settings(root: Path = ROOT) -> dict:
    """Only project .env; no shell evaluation, expansion, or global key search."""
    env_path = root / ".env"
    if env_path.is_symlink():
        raise AuthoringError("Refusing a symlink .env; use a local private file.")
    file_values = {}
    if env_path.exists():
        try:
            from dotenv import dotenv_values
        except ImportError:
            raise AuthoringError("Install requirements-authoring.txt in .venv first.") from None
        file_values = dotenv_values(env_path, interpolate=False)
    def value(name: str, default: str = "") -> str:
        return str(os.environ.get(name, file_values.get(name) or default)).strip()
    model = value("OPENAI_IMAGE_MODEL", "gpt-image-1-mini")
    quality = value("OPENAI_IMAGE_QUALITY", "low")
    if model not in MODELS:
        raise AuthoringError("Unsupported image model; choose a documented model in .env. No fallback was attempted.")
    if quality not in {"low", "medium", "high"}:
        raise AuthoringError("OPENAI_IMAGE_QUALITY must be low, medium, or high.")
    key = value("OPENAI_API_KEY")
    if key.lower() in {"your-key", "your_key", "your-api-key", "replace-me"}:
        key = ""
    return {"key": key, "model": model, "quality": quality,
            "forge_total_budget_usd": value("FORGE_TOTAL_BUDGET_USD", "0.50")}


def public_settings(config: dict) -> dict:
    return {"key_present": bool(config["key"]), "model": config["model"], "quality": config["quality"]}


def prompts(root: Path = ROOT) -> dict:
    path = root / "assets/source/image_prompts.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        jobs = data["jobs"]
        if data["schema_version"] != 1 or set(jobs) != {"materials", "tavi"}:
            raise ValueError
        for name, job in jobs.items():
            if not isinstance(job, dict) or not isinstance(job.get("prompt"), str) or not 20 <= len(job["prompt"]) <= 12000:
                raise ValueError
            if job.get("background") != ("opaque" if name == "materials" else "transparent"):
                raise ValueError
        return data
    except (OSError, ValueError, KeyError, TypeError):
        raise AuthoringError("Original art prompt library is missing or invalid.") from None


def plan(config: dict, kind: str, root: Path = ROOT) -> dict:
    library = prompts(root)
    names = ["materials", "tavi"] if kind == "smoke" else [kind]
    jobs = [{"name": name, "model": config["model"], "quality": config["quality"], "size": "1024x1024",
             "output_format": "png", "background": library["jobs"][name]["background"], "n": 1,
             "prompt": library["jobs"][name]["prompt"]} for name in names]
    estimate = None
    if config["model"] == "gpt-image-1-mini":
        estimate = {"image_output_usd": round(len(jobs) * {"low": .005, "medium": .011, "high": .036}[config["quality"]], 3),
                    "excludes": "Prompt/image input charges; estimate only. Check account billing.",
                    "pricing_checked": "2026-10-25", "retirement": "2026-12-01"}
    return {"schema_version": 1, "provider": "OpenAI Images API", "content_version": "phase1-v1",
            "requests": len(jobs), "max_retries": 0, "cost_estimate": estimate, "jobs": jobs}


def request_image(key: str, payload: dict) -> tuple[bytes, dict]:
    """Fixed official endpoint, one request, no retries/fallback or error-body logs."""
    try:
        from openai import OpenAI, APIStatusError, APITimeoutError, APIConnectionError
    except ImportError:
        raise AuthoringError("Install requirements-authoring.txt in .venv first.") from None
    # Explicit base_url prevents an inherited OPENAI_BASE_URL redirecting a key.
    try:
        with OpenAI(api_key=key, base_url="https://api.openai.com/v1", max_retries=0, timeout=180.0) as client:
            response = client.images.generate(**payload)
            encoded = response.data[0].b64_json if response.data and len(response.data) == 1 else None
            if not isinstance(encoded, str) or len(encoded) > MAX_IMAGE_BYTES * 4 // 3 + 8:
                raise AuthoringError("Provider did not return one bounded base64 image; nothing was installed.")
            try:
                pixels = base64.b64decode(encoded, validate=True)
            except (ValueError, TypeError):
                raise AuthoringError("Provider image encoding is invalid; nothing was installed.") from None
            meta = {"created": response.created, "usage": {}}
            if response.usage is not None:
                for field in ("input_tokens", "output_tokens", "total_tokens"):
                    count = getattr(response.usage, field, None)
                    if type(count) is int and count >= 0:
                        meta["usage"][field] = count
            identity = getattr(response, "_request_id", None)
            if isinstance(identity, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,160}", identity):
                meta["request_id"] = identity
            return pixels, meta
    except APIStatusError as error:
        reason = {400: "Request settings rejected", 401: "API key not accepted", 403: "Model/account access denied",
                  404: "Selected model unavailable", 429: "Rate limit or account quota reached"}.get(error.status_code, "Provider request failed")
        raise AuthoringError(f"{reason} (HTTP {error.status_code}). No retry or model fallback was made.") from None
    except (APITimeoutError, APIConnectionError):
        raise AuthoringError("Provider connection failed or timed out. Billing may be uncertain; inspect your account before retrying.") from None


def validate_raw(data: bytes, background: str) -> None:
    if len(data) > MAX_IMAGE_BYTES:
        raise AuthoringError("Returned image exceeds the local byte limit.")
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.format != "PNG" or image.size != (1024, 1024) or getattr(image, "n_frames", 1) != 1:
                raise ValueError
            image.load()
            alpha = image.convert("RGBA").getchannel("A").getextrema()
            if background == "transparent" and (alpha[0] != 0 or alpha[1] != 255):
                raise AuthoringError("Sprite output lacks real transparency; retained raw art needs correction, not automatic installation.")
            if background == "opaque" and alpha != (255, 255):
                raise AuthoringError("Material output is not opaque; retained raw art needs correction.")
    except (OSError, ValueError, Image.DecompressionBombError):
        raise AuthoringError("Provider output is not a valid single-frame 1024x1024 PNG.") from None


def generate(config: dict, kind: str, root: Path = ROOT, requester=request_image) -> Path:
    if not config["key"]:
        raise AuthoringError("Add OPENAI_API_KEY to the ignored .env, then run generate. No API request was made.")
    work = plan(config, kind, root)
    run_id = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:8]
    folder = root / "build/ai-assets" / run_id
    raw = folder / "raw"
    raw.mkdir(parents=True, exist_ok=False)
    (root / "build/.gdignore").touch(exist_ok=True)
    provenance = {"schema_version": 1, "created_at": now(), "status": "in_progress", "plan": work,
                  "base_manifest_sha256": sha256((root / "assets/manifest.json").read_bytes()), "outputs": [],
                  "notice": "Original generated art candidates; visual quality and gameplay acceptance require review."}
    write_json(folder / "provenance.json", provenance)
    try:
        for job in work["jobs"]:
            name = job["name"]
            # Write before the billable request: interrupted attempts stay visible.
            attempt = {"status": "started", "started_at": now(), "job": name, "automatic_retries": 0}
            write_json(raw / (name + ".attempt.json"), attempt)
            payload = {k: v for k, v in job.items() if k != "name"}
            data, provider = requester(config["key"], payload)
            target = raw / (name + ".png")
            target.write_bytes(data) # Retain original even if local visual admission fails.
            provenance["outputs"].append({"job": name, "file": "raw/" + target.name, "sha256": sha256(data), "provider": provider})
            write_json(folder / "provenance.json", provenance)
            validate_raw(data, job["background"])
            attempt.update({"status": "received_and_decoded", "completed_at": now()})
            write_json(raw / (name + ".attempt.json"), attempt)
        provenance["status"] = "raw_ready_for_conversion"
        write_json(folder / "provenance.json", provenance)
    except Exception as error:
        provenance["status"] = "failed_or_interrupted"
        write_json(folder / "provenance.json", provenance)
        if isinstance(error, AuthoringError):
            raise AuthoringError(f"{error} Retained run: {folder}") from None
        raise AuthoringError(f"Authoring stopped; no assets installed. Inspect retained run: {folder}") from None
    return folder


def prepare(folder: Path, root: Path = ROOT) -> dict:
    # Candidate conversion is local and does not require an API key.
    from ai_asset_conversion import convert_candidate
    provenance_path = folder / "provenance.json"
    try:
        record = json.loads(provenance_path.read_text())
        if record["base_manifest_sha256"] != sha256((root / "assets/manifest.json").read_bytes()):
            raise AuthoringError("This run belongs to another base asset bundle; start from its matching checkout.")
        if record["status"] != "raw_ready_for_conversion":
            raise AuthoringError("Only successfully decoded raw runs can be prepared; no implicit retries.")
        for output in record["outputs"]:
            if output["file"] not in {"raw/materials.png", "raw/tavi.png"} or sha256((folder / output["file"]).read_bytes()) != output["sha256"]:
                raise AuthoringError("Raw art differs from retained generation provenance.")
        result = convert_candidate(root, folder / "raw", folder / "candidate")
        record["status"] = "candidate_ready_for_visual_review"
        write_json(provenance_path, record)
        return result
    except (OSError, ValueError, KeyError, TypeError):
        raise AuthoringError("Run metadata or candidate conversion is invalid; original game assets remain intact.") from None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("status", help="Report key presence only; never print credentials")
    dry = sub.add_parser("plan", help="No API request; show prompts/settings/output cost estimate")
    dry.add_argument("--kind", choices=["smoke", "materials", "tavi"], default="smoke")
    live = sub.add_parser("generate", help="Make 1 or 2 billable calls; no retries, no automatic install")
    live.add_argument("--kind", choices=["smoke", "materials", "tavi"], default="smoke")
    local = sub.add_parser("prepare", help="Convert retained raw art to a new visual-review candidate")
    local.add_argument("run", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "prepare":
            result = prepare(args.run.resolve())
            print(json.dumps(result, indent=2))
        else:
            config = settings()
            if args.command == "status":
                print(json.dumps(public_settings(config), indent=2))
            elif args.command == "plan":
                print(json.dumps(plan(config, args.kind), indent=2))
            else:
                folder = generate(config, args.kind)
                print(f"Raw art retained at {folder}. Run prepare after generation; inspect the candidate before promotion.")
        return 0
    except AuthoringError as error:
        print("AI authoring: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
