"""Unit tests: security boundaries, persistence calls and failure handling; no AWS calls."""
import base64
import importlib.util
import os
from pathlib import Path
from unittest.mock import MagicMock
import pytest
import psycopg
os.environ["APP_TESTING"] = "1"
spec = importlib.util.spec_from_file_location("webapp", Path(__file__).parents[1] / "app/app.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
CFG = {"username": "tester", "password": "test-only-password", "session_key": "test-only-key", "db_username": "webapp_runtime", "db_password": "test-only-db"}
AUTH = {"Authorization": "Basic " + base64.b64encode(b"tester:test-only-password").decode()}
@pytest.fixture
def setup():
    db = MagicMock()
    conn = db.return_value.__enter__.return_value
    conn.execute.return_value.fetchall.return_value = []
    app = module.create_app(lambda: CFG, db)
    app.config.update(TESTING=True)
    return app.test_client(), db, conn

def test_unauthenticated_read_and_write_blocked(setup):
    client, db, _ = setup
    assert client.get("/").status_code == 401
    assert client.post("/tasks", data={"title": "denied"}).status_code == 401
    db.assert_not_called()

def test_liveness_does_not_require_db(setup):
    client, db, _ = setup
    assert client.get("/health").status_code == 200
    db.assert_not_called()

def test_readiness_returns_503_on_db_failure(setup):
    client, db, _ = setup
    db.side_effect = psycopg.OperationalError("offline")
    assert client.get("/ready").status_code == 503

def test_csrf_required(setup):
    client, db, _ = setup
    assert client.post("/tasks", headers=AUTH, data={"title": "task"}).status_code == 400
    db.assert_not_called()

def test_write_is_parameterized(setup):
    client, _, conn = setup
    client.get("/", headers=AUTH, base_url="https://localhost")
    with client.session_transaction(base_url="https://localhost") as session:
        token = session["csrf_token"]
    payload = "x'); DROP TABLE tasks; --"
    result = client.post("/tasks", headers=AUTH, data={"title": payload, "csrf_token": token}, base_url="https://localhost")
    assert result.status_code == 303
    conn.execute.assert_called_with("INSERT INTO public.tasks (title) VALUES (%s)", (payload,))

def test_output_escaping_and_security_headers(setup):
    from datetime import datetime, timezone
    client, _, conn = setup
    conn.execute.return_value.fetchall.return_value = [(1, '<script>alert(1)</script>', datetime.now(timezone.utc))]
    response = client.get("/", headers=AUTH)
    assert b"&lt;script&gt;" in response.data
    assert b"<script>alert" not in response.data
    assert response.headers["Cache-Control"] == "no-store"
    assert response.headers["X-Frame-Options"] == "DENY"

def test_title_limit(setup):
    client, _, conn = setup
    client.get("/", headers=AUTH, base_url="https://localhost")
    with client.session_transaction(base_url="https://localhost") as session:
        token = session["csrf_token"]
    conn.execute.reset_mock()
    assert client.post("/tasks", headers=AUTH, data={"title": "x" * 201, "csrf_token": token}, base_url="https://localhost").status_code == 400
    conn.execute.assert_not_called()

def test_readiness_queries_runtime_table(setup):
    client, _, conn = setup
    assert client.get("/ready").status_code == 200
    conn.execute.assert_called_with("SELECT id FROM public.tasks LIMIT 1")


def test_non_ascii_credentials_return_401(setup):
    client, db, _ = setup
    auth = {"Authorization": "Basic " + base64.b64encode("é:wrong".encode()).decode()}
    assert client.get("/", headers=auth).status_code == 401
    db.assert_not_called()

def test_csp_allows_versioned_cdn_assets(setup, monkeypatch):
    client, _, _ = setup
    monkeypatch.setenv("STATIC_BASE_URL", "https://static.example.com/abc123")
    response = client.get("/", headers=AUTH)
    assert "style-src 'self' https://static.example.com;" in response.headers["Content-Security-Policy"]
    assert b"https://static.example.com/abc123/style.css" in response.data
