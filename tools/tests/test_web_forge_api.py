"""HTTP boundary tests; install requirements-web.txt to run these optional tests."""
from __future__ import annotations

import base64
import asyncio
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from server.store import Store
from tools.forge.jobs import write_json
from tools.tests.test_forge_provider import png_bytes

HAS_HTTP = all(importlib.util.find_spec(name) for name in ("fastapi", "httpx"))


class ASGIClient:
    """Exercise real ASGI routes on one loop, without a thread portal/socket."""
    def __init__(self, app, base_url):
        import httpx
        self.runner = asyncio.Runner()
        self.lifespan = app.router.lifespan_context(app)
        self.client = httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url=base_url)

    @property
    def cookies(self):
        return self.client.cookies

    def __enter__(self):
        self.runner.run(self.lifespan.__aenter__())
        return self

    def __exit__(self, *args):
        self.runner.run(self.client.aclose())
        self.runner.run(self.lifespan.__aexit__(*args))
        self.runner.close()

    def get(self, url, **kwargs):
        return self.runner.run(self.client.get(url, **kwargs))

    def post(self, url, **kwargs):
        return self.runner.run(self.client.post(url, **kwargs))

    def delete(self, url, **kwargs):
        return self.runner.run(self.client.delete(url, **kwargs))

    def options(self, url, **kwargs):
        return self.runner.run(self.client.options(url, **kwargs))


@unittest.skipUnless(HAS_HTTP, "optional hosted API dependencies are not installed")
class HostedForgeApiTests(unittest.TestCase):
    def setUp(self):
        from server.app import create_app
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "data"
        self.store = Store(self.root)
        self.invite = self.store.create_invite("HTTP fixture")
        self.client = ASGIClient(create_app(self.root, public_origin="https://testserver"), base_url="https://testserver")
        self.client.__enter__()
        self.addCleanup(self.client.__exit__, None, None, None)
        self.headers = {"Origin": "https://testserver", "X-Gloamthread-Request": "1"}
        self.source = base64.b64encode(png_bytes()).decode()

    def login(self, code=None):
        return self.client.post("/api/forge/session", json={"code": code or self.invite["code"]}, headers=self.headers)

    def create(self, **extra):
        return self.client.post("/api/forge/jobs", json={"source_png": self.source, **extra}, headers=self.headers)

    def test_public_configuration_and_health_never_expose_provider_or_invites(self):
        write_json(self.root / "worker.json", {"ready": True, "key_present": True,
                                               "key": "sk-fixture-never-publish", "env": "/private/path/.env"})
        result = self.client.get("/api/forge/configuration")
        self.assertEqual(result.status_code, 200)
        self.assertFalse(result.json()["authenticated"])
        self.assertTrue(result.json()["key_present"])
        self.assertNotIn("sk-fixture", result.text)
        self.assertNotIn("/private/path", result.text)
        self.assertNotIn(self.invite["code"], result.text)
        self.assertEqual(result.headers["cache-control"], "no-store")
        self.assertEqual(self.client.get("/healthz").json(), {"ok": True})
        self.assertEqual(self.client.get("/docs").status_code, 404)

    def test_secure_cookie_login_logout_and_unauthenticated_job_denial(self):
        self.assertEqual(self.create().status_code, 401)
        response = self.login()
        self.assertEqual(response.status_code, 200)
        cookie = response.headers["set-cookie"].lower()
        self.assertIn("httponly", cookie)
        self.assertIn("secure", cookie)
        self.assertIn("samesite=strict", cookie)
        self.assertTrue(self.client.get("/api/forge/configuration").json()["authenticated"])
        self.assertEqual(self.client.delete("/api/forge/session", headers=self.headers).status_code, 200)
        self.assertEqual(self.create().status_code, 401)

    def test_mutations_refuse_cross_site_origin_and_missing_origin_header(self):
        for headers in ({"Origin": "https://attacker.invalid"}, {},
                        {"Origin": "https://testserver", "Sec-Fetch-Site": "cross-site"}):
            response = self.client.post("/api/forge/session", json={"code": self.invite["code"]}, headers=headers)
            self.assertEqual(response.status_code, 403)
        # Same-origin Godot requests may omit Origin; a non-simple header is
        # allowed because cross-origin scripts cannot pass CORS preflight.
        response = self.client.post("/api/forge/session", json={"code": self.invite["code"]}, headers={"X-Gloamthread-Request": "1"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.client.options("/api/forge/jobs", headers={"Origin": "https://attacker.invalid"}).headers.get("access-control-allow-origin"), None)

    def test_owner_isolation_list_cancel_snapshot_and_operation(self):
        self.login()
        response = self.create()
        self.assertEqual(response.status_code, 201)
        identity = response.json()["job_id"]
        second = self.store.create_invite("second fixture")
        self.login(second["code"])
        self.assertEqual(self.client.get("/api/forge/jobs").json()["jobs"], [])
        for suffix in ("", "/snapshot"):
            self.assertEqual(self.client.get("/api/forge/jobs/" + identity + suffix).status_code, 404)
        for suffix, payload in (("/cancel", {}), ("/operations", {"command": "analyse", "idempotency_key": "fixture-key"})):
            self.assertEqual(self.client.post("/api/forge/jobs/" + identity + suffix, json=payload, headers=self.headers).status_code, 404)

    def test_duplicate_operations_and_polling_survive_new_http_session(self):
        self.login()
        identity = self.create().json()["job_id"]
        endpoint = "/api/forge/jobs/" + identity
        payload = {"command": "analyse", "idempotency_key": "fixture-duplicate"}
        first = self.client.post(endpoint + "/operations", json=payload, headers=self.headers)
        again = self.client.post(endpoint + "/operations", json=payload, headers=self.headers)
        self.assertEqual(first.status_code, 202)
        self.assertEqual(first.json()["operation_id"], again.json()["operation_id"])
        self.client.cookies.clear()
        self.login()
        self.assertEqual(self.client.get(endpoint).json()["state"], "queued")
        self.assertEqual(self.client.get(endpoint + "/snapshot").status_code, 409)
        self.assertEqual(len(self.client.get("/api/forge/jobs").json()["jobs"]), 1)
        self.assertEqual(self.client.post(endpoint + "/cancel", headers=self.headers).status_code, 200)
        self.assertEqual(self.client.get(endpoint).json()["state"], "cancelled")

    def test_revoked_session_loses_all_artifact_access(self):
        self.login()
        identity = self.create().json()["job_id"]
        self.store.revoke(self.invite["owner_id"])
        self.assertEqual(self.client.get("/api/forge/jobs/" + identity + "/snapshot").status_code, 401)
        self.assertEqual(self.login().status_code, 401)

    def test_malformed_upload_unknown_fields_and_nonfinite_json_are_rejected(self):
        self.login()
        for payload in ({"source_png": "not base64"}, {"source_png": self.source, "source_image": "/etc/passwd"},
                        {"source_png": self.source, "parent_job_id": ["invalid"]},
                        {"source_png": self.source, "art_mode": ["invalid"]}):
            response = self.client.post("/api/forge/jobs", json=payload, headers=self.headers)
            self.assertIn(response.status_code, (400, 404))
        for data in (b'{"source_png":NaN}', b'{"a":1,"a":2}'):
            self.assertEqual(self.client.post("/api/forge/jobs", content=data, headers=self.headers).status_code, 400)
        response = self.client.post("/api/forge/jobs", content=b"{}", headers={**self.headers, "Content-Length": str(49 * 1024 * 1024)})
        self.assertEqual(response.status_code, 413)
        identity = self.create().json()["job_id"]
        endpoint = "/api/forge/jobs/" + identity + "/operations"
        response = self.client.post(endpoint, json={"command": [], "idempotency_key": "fixture-key"}, headers=self.headers)
        self.assertEqual(response.status_code, 400)

    def test_snapshots_expose_only_allowed_private_draft_data(self):
        self.login()
        identity = self.create().json()["job_id"]
        path = self.store.require_job(self.invite["owner_id"], identity).parent
        (path / ".env").write_text("OPENAI_API_KEY=sk-must-never-download")
        response = self.client.get("/api/forge/jobs/" + identity + "/snapshot")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(set(response.json()["files"]), {"source.png"})
        self.assertNotIn("sk-must-never-download", response.text)
        self.assertNotIn(str(path), response.text)


if __name__ == "__main__":
    unittest.main()
