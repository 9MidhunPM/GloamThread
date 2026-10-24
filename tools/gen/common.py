"""Small shared output/provenance helpers; no engine resources or network input."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def record(root: Path, asset_id: str, kind: str, path: Path, sources: list[str],
           diagnostic: bool = False, **metadata: object) -> dict:
    return {"id": asset_id, "kind": kind, "path": path.relative_to(root).as_posix(),
            "sha256": digest(path), "diagnostic": diagnostic,
            "sources": [{"path": source, "sha256": digest(root / source)} for source in sources],
            **metadata}
