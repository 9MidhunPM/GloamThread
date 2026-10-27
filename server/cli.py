"""Operator-only invitation commands. Codes are shown once, never stored raw."""
from __future__ import annotations

import argparse
import json
import os

from .store import ServiceError, Store


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-root", default=os.environ.get("FORGE_DATA_ROOT", "/data/forge"))
    sub = parser.add_subparsers(dest="command", required=True)
    create = sub.add_parser("invite", help="Create a revocable invite; keep its one-time output private")
    create.add_argument("--label", required=True)
    revoke = sub.add_parser("revoke", help="Revoke an invitation and cancel its queued/later stages")
    revoke.add_argument("--owner-id", required=True)
    sub.add_parser("list", help="List labels and revocation state, never invitation codes")
    args = parser.parse_args(argv)
    store = Store(args.data_root)
    try:
        if args.command == "invite":
            print(json.dumps(store.create_invite(args.label)))
        elif args.command == "revoke":
            store.revoke(args.owner_id)
            print(json.dumps({"ok": True, "owner_id": args.owner_id}))
        else:
            with store.connect() as db:
                print(json.dumps([dict(r) for r in db.execute("SELECT owner_id,label,revoked,created_at FROM invites ORDER BY created_at")]))
    except ServiceError as error:
        print(json.dumps({"ok": False, "error": str(error)}))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
