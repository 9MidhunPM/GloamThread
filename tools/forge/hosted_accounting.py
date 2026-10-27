"""SQLite request reservations for hosted workers; native authoring keeps JSON."""
from __future__ import annotations

from datetime import datetime, timezone
from contextlib import contextmanager
import hashlib
from pathlib import Path
import sqlite3

from .provider import ForgeError

AMOUNTS = {"analyse": 50000, "parts": 100000, "theme": 100000}


class SqliteAccounting:
    def __init__(self, database: Path, owner_id: str):
        self.database = Path(database)
        self.owner_id = owner_id

    @staticmethod
    def job_key(job: Path) -> str:
        return hashlib.sha256(str(job).encode()).hexdigest()

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.database, timeout=15)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA synchronous=FULL")
        try:
            with db:
                yield db
        finally:
            db.close()

    def ledger(self) -> dict:
        with self.connect() as db:
            records = [dict(r) for r in db.execute("SELECT job_key AS job,kind,cache_key,microusd,state,created_at FROM reservations")]
        return {"schema_version": 1, "cap_microusd": None,
                "reserved_usd": sum(x["microusd"] for x in records) / 1000000,
                "reservations": records}

    def reserve(self, job: Path, kind: str, key: str):
        try:
            with self.connect() as db:
                db.execute("INSERT INTO reservations VALUES(?,?,?,?,?,?,?)",
                           (self.job_key(job), self.owner_id, kind, key, AMOUNTS[kind], "reserved",
                            datetime.now(timezone.utc).isoformat(timespec="seconds")))
        except sqlite3.IntegrityError:
            raise ForgeError("This request was already attempted. Its reservation is retained; automatic retries are disabled.") from None

    def attempted(self, job: Path, kinds: list[str]) -> bool:
        with self.connect() as db:
            rows = db.execute("SELECT kind FROM reservations WHERE job_key=? AND owner_id=?",
                              (self.job_key(job), self.owner_id)).fetchall()
        return any(row[0] in kinds for row in rows)

    def mark(self, job: Path, kind: str, state: str):
        if state not in {"reserved", "received", "uncertain"}:
            raise ForgeError("Invalid request accounting state.")
        with self.connect() as db:
            db.execute("UPDATE reservations SET state=? WHERE job_key=? AND owner_id=? AND kind=?",
                       (state, self.job_key(job), self.owner_id, kind))

    def status(self, job: Path | None = None, required: int = 0) -> dict:
        with self.connect() as db:
            total = db.execute("SELECT COALESCE(SUM(microusd),0) FROM reservations WHERE owner_id=?", (self.owner_id,)).fetchone()[0]
            local = 0 if job is None else db.execute("SELECT COALESCE(SUM(microusd),0) FROM reservations WHERE owner_id=? AND job_key=?", (self.owner_id, self.job_key(job))).fetchone()[0]
        return {"limits_enabled": False, "total_limit_usd": None, "total_reserved_usd": total / 1000000,
                "total_remaining_usd": None, "job_limit_usd": None, "job_reserved_usd": local / 1000000,
                "job_remaining_usd": None, "required_usd": required / 1000000}
