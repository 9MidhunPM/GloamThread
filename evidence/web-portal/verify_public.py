#!/usr/bin/env python3
"""Verify the deployed public payload without printing private scan values."""
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path(__file__).resolve().parent


def private_values():
    values = []
    for filename, key in ((".env", "OPENAI_API_KEY"), (".env.creator-invite", "GLOAMTHREAD_CREATOR_INVITE")):
        path = ROOT / filename
        if not path.is_file():
            continue
        for line in path.read_text().splitlines():
            if line.startswith(key + "="):
                value = line.split("=", 1)[1].strip().strip("\"'")
                if len(value) > 12:
                    values.append(value.encode())
    return values


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="https://gloamthread.midhunpm.in/")
    parser.add_argument("--expected-commit", default="37f5bff1f056c7811bb84a4260c1f95ee660d03d")
    args = parser.parse_args()
    base = args.base.rstrip("/") + "/"

    def fetch(name):
        # curl follows the host's working HTTPS route; raw urllib sockets can
        # stall on an unreachable CDN address in this verification environment.
        with tempfile.TemporaryDirectory(prefix="gloam-public-") as folder:
            body, headers = Path(folder) / "body", Path(folder) / "headers"
            subprocess.run([
                "curl", "--fail", "--silent", "--show-error", "--location",
                "--compressed", "--connect-timeout", "10", "--max-time", "90",
                "--user-agent", "Mozilla/5.0", "--output", str(body),
                "--dump-header", str(headers), base + name,
            ], check=True, capture_output=True)
            blocks = headers.read_text().replace("\r", "").strip().split("\n\n")
            response = next(block for block in reversed(blocks) if block.startswith("HTTP/"))
            lines = response.splitlines()
            fields = {key.lower(): value.strip() for line in lines[1:] if ":" in line for key, value in [line.split(":", 1)]}
            return body.read_bytes(), {"status": int(lines[0].split()[1]), "cache_control": fields.get("cache-control"), "content_type": fields.get("content-type")}

    raw, _ = fetch("BUILD.json")
    build = json.loads(raw)
    if build.get("implementation_commit") != args.expected_commit or build.get("dirty_qa_build") is not False:
        raise ValueError("The public site is not the expected clean release.")
    values = private_values()

    def verify(item):
        name, expected = item
        if re.fullmatch(r"[A-Za-z0-9_.-]+", name) is None:
            raise ValueError("Unexpected public filename.")
        data, metadata = fetch(name)
        digest = hashlib.sha256(data).hexdigest()
        if len(data) != expected["bytes"] or digest != expected["sha256"]:
            raise ValueError("Public file size/hash mismatch: " + name)
        if any(value in data for value in values):
            raise ValueError("A private scan value was found in the public payload.")
        print("PASS", name, flush=True)
        return name, {**metadata, "bytes": len(data), "sha256": digest}

    with ThreadPoolExecutor(max_workers=4) as pool:
        files = dict(pool.map(verify, build["files"].items()))
    health, health_metadata = fetch("healthz")
    configuration, configuration_metadata = fetch("api/forge/configuration")
    config = json.loads(configuration)
    if health.strip() != b"ok" or config.get("worker_ready") is not True:
        raise ValueError("Public web/Forge readiness check failed.")
    report = {
        "recorded_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "base": base, "implementation_commit": build["implementation_commit"],
        "dirty_qa_build": False, "files": files,
        "known_private_values_absent": True, "private_values_checked": len(values),
        "health": health_metadata, "forge": {**configuration_metadata, "worker_ready": True},
    }
    (OUTPUT / "BUILD.json").write_bytes(raw)
    (OUTPUT / "public-integrity.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"PASS {len(files)} public file sizes/hashes; clean source; private values absent; web/Forge ready")


if __name__ == "__main__":
    main()
