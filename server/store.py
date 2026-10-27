"""Durable invitations, ownership and a deliberately single-worker job queue."""
from __future__ import annotations

from contextlib import contextmanager
import hashlib
import json
from pathlib import Path
import re
import secrets
import sqlite3
import time

from tools.forge.jobs import atomic_bytes, read_json, write_json

ID = re.compile(r"[0-9a-f]{32}")
COMMANDS = {"analyse", "generate", "bake"}


class ServiceError(Exception):
    def __init__(self, message: str, status: int = 400):
        super().__init__(message)
        self.status = status


def token_hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


class Store:
    def __init__(self, root: Path | str):
        original = Path(root).absolute()
        if original.is_symlink():
            raise ValueError("Authoring data must not be a symlink.")
        self.root = original.resolve()
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.db_path = self.root / "forge.sqlite3"
        with self.connect() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS invites (
                    owner_id TEXT PRIMARY KEY, code_hash TEXT NOT NULL UNIQUE,
                    label TEXT NOT NULL, revoked INTEGER NOT NULL DEFAULT 0,
                    created_at REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY, owner_id TEXT NOT NULL,
                    expires_at REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS jobs (
                    job_id TEXT PRIMARY KEY, owner_id TEXT NOT NULL,
                    created_at REAL NOT NULL, parent_job_id TEXT);
                CREATE INDEX IF NOT EXISTS jobs_owner ON jobs(owner_id);
                CREATE TABLE IF NOT EXISTS operations (
                    operation_id TEXT PRIMARY KEY, job_id TEXT NOT NULL,
                    owner_id TEXT NOT NULL, idempotency_key TEXT NOT NULL,
                    payload_hash TEXT NOT NULL, payload TEXT NOT NULL,
                    command TEXT NOT NULL, state TEXT NOT NULL,
                    message TEXT NOT NULL, created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    UNIQUE(owner_id, idempotency_key));
                CREATE INDEX IF NOT EXISTS operations_queue ON operations(state, created_at);
                CREATE TABLE IF NOT EXISTS reservations (
                    job_key TEXT NOT NULL, owner_id TEXT NOT NULL,
                    kind TEXT NOT NULL, cache_key TEXT NOT NULL,
                    microusd INTEGER NOT NULL, state TEXT NOT NULL,
                    created_at TEXT NOT NULL, PRIMARY KEY(job_key, kind));
                CREATE INDEX IF NOT EXISTS reservations_owner ON reservations(owner_id,job_key);
                CREATE TABLE IF NOT EXISTS login_attempts (
                    identity TEXT NOT NULL, attempted_at REAL NOT NULL);
                CREATE INDEX IF NOT EXISTS login_time ON login_attempts(attempted_at);
            """)
        self.db_path.chmod(0o600)

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.db_path, timeout=15, isolation_level=None)
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA journal_mode=WAL")
        db.execute("PRAGMA synchronous=FULL")
        db.execute("PRAGMA busy_timeout=15000")
        try:
            yield db
        finally:
            db.close()

    @contextmanager
    def transaction(self):
        with self.connect() as db:
            db.execute("BEGIN IMMEDIATE")
            try:
                yield db
                db.execute("COMMIT")
            except BaseException:
                db.execute("ROLLBACK")
                raise

    def create_invite(self, label: str) -> dict:
        if not isinstance(label, str) or not 1 <= len(label.strip()) <= 80:
            raise ServiceError("Invite label must contain 1–80 characters.")
        owner = secrets.token_hex(16)
        code = secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute("INSERT INTO invites(owner_id,code_hash,label,created_at) VALUES(?,?,?,?)",
                       (owner, token_hash(code), label.strip(), time.time()))
        return {"owner_id": owner, "code": code, "label": label.strip()}

    def login(self, code: str, identity: str) -> str:
        now = time.time()
        with self.transaction() as db:
            db.execute("DELETE FROM login_attempts WHERE attempted_at < ?", (now - 300,))
            count = db.execute("SELECT COUNT(*) FROM login_attempts WHERE identity=?", (token_hash(identity),)).fetchone()[0]
            if count >= 10:
                raise ServiceError("Too many invite attempts. Try again in five minutes.", 429)
            db.execute("INSERT INTO login_attempts VALUES(?,?)", (token_hash(identity), now))
        if not isinstance(code, str) or not 20 <= len(code) <= 128:
            raise ServiceError("Invite code is invalid or revoked.", 401)
        with self.transaction() as db:
            row = db.execute("SELECT owner_id FROM invites WHERE code_hash=? AND revoked=0", (token_hash(code),)).fetchone()
            if row is None:
                raise ServiceError("Invite code is invalid or revoked.", 401)
            token = secrets.token_urlsafe(32)
            db.execute("DELETE FROM sessions WHERE expires_at < ?", (now,))
            db.execute("INSERT INTO sessions VALUES(?,?,?)", (token_hash(token), row[0], now + 30 * 86400))
        return token

    def owner_for_session(self, token: str | None) -> str:
        if not isinstance(token, str) or len(token) > 128:
            raise ServiceError("Unlock the forge with your invitation code.", 401)
        with self.connect() as db:
            row = db.execute("SELECT s.owner_id FROM sessions s JOIN invites i USING(owner_id) "
                             "WHERE s.token_hash=? AND s.expires_at>? AND i.revoked=0",
                             (token_hash(token), time.time())).fetchone()
        if row is None:
            raise ServiceError("Invite session expired or was revoked.", 401)
        return row[0]

    def logout(self, token: str | None):
        if token:
            with self.connect() as db:
                db.execute("DELETE FROM sessions WHERE token_hash=?", (token_hash(token),))

    def revoke(self, owner: str):
        with self.transaction() as db:
            if db.execute("UPDATE invites SET revoked=1 WHERE owner_id=?", (owner,)).rowcount != 1:
                raise ServiceError("Invitation not found.", 404)
            db.execute("DELETE FROM sessions WHERE owner_id=?", (owner,))
            rows = db.execute("SELECT job_id FROM operations WHERE owner_id=? AND state IN ('queued','running')", (owner,)).fetchall()
            db.execute("UPDATE operations SET state='cancelled',message=?,updated_at=? WHERE owner_id=? AND state='queued'",
                       ("Invitation revoked before this operation started.", time.time(), owner))
        for row in rows:
            atomic_bytes(self.job_path(owner, row[0]).parent / "cancel", b"revoked\n")

    def active_invite(self, owner: str) -> bool:
        with self.connect() as db:
            row = db.execute("SELECT revoked FROM invites WHERE owner_id=?", (owner,)).fetchone()
        return row is not None and row[0] == 0

    def job_path(self, owner: str, job: str) -> Path:
        if not isinstance(owner, str) or not isinstance(job, str) or ID.fullmatch(owner) is None or ID.fullmatch(job) is None:
            raise ServiceError("Job not found.", 404)
        return self.root / "owners" / owner / "jobs" / job / "job.json"

    def require_job(self, owner: str, job: str) -> Path:
        self.job_path(owner, job)
        with self.connect() as db:
            row = db.execute("SELECT job_id FROM jobs WHERE owner_id=? AND job_id=?", (owner, job)).fetchone()
        if row is None:
            raise ServiceError("Job not found.", 404)
        path = self.job_path(owner, job)
        if path.parent.resolve() != path.parent or path.is_symlink() or not path.is_file():
            raise ServiceError("Retained job is unavailable.", 409)
        return path

    def record_job(self, owner: str, job: str, parent: str | None):
        with self.connect() as db:
            db.execute("INSERT INTO jobs VALUES(?,?,?,?)", (job, owner, time.time(), parent))

    def list_jobs(self, owner: str) -> list:
        with self.connect() as db:
            return [dict(row) for row in db.execute("SELECT job_id,created_at FROM jobs WHERE owner_id=? ORDER BY created_at DESC LIMIT 100", (owner,))]

    def enqueue(self, owner: str, job: str, command: str, key: str, payload: dict) -> dict:
        if not isinstance(command, str) or command not in COMMANDS:
            raise ServiceError("Choose Analyse, Generate or Convert saved artwork.")
        if not isinstance(key, str) or re.fullmatch(r"[A-Za-z0-9_-]{8,128}", key) is None:
            raise ServiceError("A bounded idempotency key is required.")
        serialized = json.dumps(payload, sort_keys=True, separators=(",", ":"), allow_nan=False)
        payload_hash = token_hash(serialized)
        now = time.time()
        with self.transaction() as db:
            previous = db.execute("SELECT operation_id,payload_hash,job_id FROM operations WHERE owner_id=? AND idempotency_key=?", (owner, key)).fetchone()
            if previous:
                if previous[1] != payload_hash or previous[2] != job:
                    raise ServiceError("This operation key was already used with different inputs.", 409)
                return {"ok": True, "operation_id": previous[0], "reused": True}
            if db.execute("SELECT 1 FROM operations WHERE owner_id=? AND state IN ('queued','running')", (owner,)).fetchone():
                raise ServiceError("Your current creation operation is still finishing.", 409)
            if db.execute("SELECT COUNT(*) FROM operations WHERE state='queued'").fetchone()[0] >= 64:
                raise ServiceError("The creation queue is full. Try again later.", 503)
            operation = secrets.token_hex(16)
            db.execute("INSERT INTO operations VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                       (operation, job, owner, key, payload_hash, serialized, command, "queued",
                        "Queued for " + command + ".", now, now))
        return {"ok": True, "operation_id": operation, "reused": False}

    def latest_operation(self, owner: str, job: str) -> dict | None:
        with self.connect() as db:
            row = db.execute("SELECT operation_id,command,state,message FROM operations WHERE owner_id=? AND job_id=? ORDER BY created_at DESC LIMIT 1", (owner, job)).fetchone()
        return dict(row) if row else None

    def cancel(self, owner: str, job: str):
        path = self.require_job(owner, job)
        with self.connect() as db:
            db.execute("UPDATE operations SET state='cancelled',message=?,updated_at=? WHERE owner_id=? AND job_id=? AND state='queued'",
                       ("Cancelled before this operation started.", time.time(), owner, job))
        atomic_bytes(path.parent / "cancel", b"cancelled\n")

    def claim(self) -> dict | None:
        with self.transaction() as db:
            # An OS flock in worker.main ensures only one worker calls claim/run.
            row = db.execute("SELECT o.* FROM operations o JOIN invites i USING(owner_id) WHERE o.state='queued' AND i.revoked=0 ORDER BY o.created_at LIMIT 1").fetchone()
            if row is None:
                return None
            db.execute("UPDATE operations SET state='running',message='Starting operation.',updated_at=? WHERE operation_id=?", (time.time(), row["operation_id"]))
            return dict(row)

    def finish(self, operation: str, state: str, message: str):
        with self.connect() as db:
            db.execute("UPDATE operations SET state=?,message=?,updated_at=? WHERE operation_id=?", (state, message, time.time(), operation))

    def recover_interrupted(self):
        with self.transaction() as db:
            rows = db.execute("SELECT owner_id,job_id,operation_id,command FROM operations WHERE state='running'").fetchall()
            for row in rows:
                message = "The worker stopped during this operation. No automatic retry was made; provider billing may be uncertain."
                db.execute("UPDATE operations SET state='uncertain',message=?,updated_at=? WHERE operation_id=?", (message, time.time(), row["operation_id"]))
                path = self.job_path(row["owner_id"], row["job_id"])
                # A cancel marker prevents a fresh command key from replaying this job.
                atomic_bytes(path.parent / "cancel", b"interrupted\n")
                write_json(path.parent / "status.json", {"state": "uncertain", "message": message})
                db.execute("UPDATE reservations SET state='uncertain' WHERE job_key=? AND state='reserved'", (token_hash(str(path)),))
