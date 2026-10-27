#!/usr/bin/env python3
"""Send the existing ignored key to a worker-only Docker volume over SSH stdin."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess

from dotenv import dotenv_values


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", required=True, help="An authorized SSH host alias")
    parser.add_argument("--volume", default="gloamthread-web-forge-secrets")
    parser.add_argument("--env-file", type=Path, default=Path(".env"))
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,100}", args.volume):
        parser.error("Unsafe Docker volume name")
    if args.env_file.is_symlink() or not args.env_file.is_file():
        parser.error("The existing ignored env file must be a regular file")
    values = dotenv_values(args.env_file)
    key = values.get("OPENAI_API_KEY")
    if not key or not key.startswith("sk-"):
        parser.error("No usable provider key is configured; nothing was transferred")
    selected = {name: values[name] for name in ("OPENAI_API_KEY", "OPENAI_IMAGE_MODEL", "OPENAI_IMAGE_QUALITY") if values.get(name)}
    payload = "".join(name + "=" + json.dumps(value) + "\n" for name, value in selected.items()).encode()
    # Secret bytes never appear in command arguments, files in this checkout,
    # stdout, stderr or the Docker environment. Only the worker mounts this volume.
    script = "import os,sys; p='/secrets/provider.env'; data=sys.stdin.buffer.read(65537); assert len(data)<=65536; f=os.open(p,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600); os.write(f,data); os.fsync(f); os.fchown(f,10001,10001); os.close(f)"
    command = "docker volume create " + shlex.quote(args.volume) + " >/dev/null && docker run --rm -i --user root -v " + shlex.quote(args.volume + ":/secrets") + " python:3.12-slim-bookworm python -c " + shlex.quote(script)
    result = subprocess.run(["ssh", "-o", "BatchMode=yes", args.host, command], input=payload, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if result.returncode:
        raise SystemExit("Secret transfer failed; provider credentials were not printed. Check SSH and Docker access.")
    print("Configured OPENAI_API_KEY in worker-only volume " + args.volume + "; plaintext was not logged.")


if __name__ == "__main__":
    main()
