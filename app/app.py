"""Small authenticated task board. AWS credentials come only from the EC2 role."""
import hmac
import json
import logging
import os
import secrets
import time
from functools import lru_cache
from urllib.parse import urlsplit

import boto3
import psycopg
from flask import Flask, Response, abort, redirect, render_template, request, session, url_for

@lru_cache(maxsize=1)
def secret_client():
    return boto3.client("secretsmanager")

@lru_cache(maxsize=2)
def read_secret(arn, minute):
    # Bounded cache; refreshed on the next request after the minute changes.
    return json.loads(secret_client().get_secret_value(SecretId=arn)["SecretString"])

def settings():
    if os.environ.get("LOCAL_DEVELOPMENT") == "1":
        return {"username": os.environ["DEMO_USERNAME"], "password": os.environ["DEMO_PASSWORD"],
                "session_key": os.environ["SESSION_KEY"], "db_username": os.environ["DB_USER"],
                "db_password": os.environ["DB_PASSWORD"]}
    return read_secret(os.environ["APP_SECRET_ARN"], int(time.time() // 60))

def connect_db(cfg):
    local = os.environ.get("LOCAL_DEVELOPMENT") == "1"
    options = {} if local else {"sslrootcert": os.environ["DB_SSLROOTCERT"]}
    return psycopg.connect(host=os.environ.get("DB_HOST", "localhost"),
                           port=int(os.environ.get("DB_PORT", "5432")),
                           dbname=os.environ.get("DB_NAME", "webapp"),
                           user=cfg["db_username"], password=cfg["db_password"],
                           sslmode="disable" if local else "verify-full",
                           connect_timeout=3, options="-c statement_timeout=3000", **options)

def create_app(config_loader=settings, db_factory=connect_db):
    app = Flask(__name__, root_path=os.path.dirname(os.path.abspath(__file__)))
    app.config.update(SECRET_KEY=config_loader()["session_key"], MAX_CONTENT_LENGTH=8192,
                      SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE="Lax",
                      SESSION_COOKIE_SECURE=os.environ.get("LOCAL_DEVELOPMENT") != "1")

    @app.before_request
    def authenticate():
        if request.path in ("/health", "/ready") or request.path.startswith("/static/"):
            return None
        cfg = config_loader()
        auth = request.authorization
        valid = auth and auth.type == "basic" and hmac.compare_digest((auth.username or "").encode(), cfg["username"].encode()) and hmac.compare_digest((auth.password or "").encode(), cfg["password"].encode())
        if not valid:
            return Response("Authentication required", 401, {"WWW-Authenticate": 'Basic realm="AWS learning project", charset="UTF-8"'})
        if request.method == "POST":
            token = session.get("csrf_token", "")
            if not token or not hmac.compare_digest(request.form.get("csrf_token", "").encode(), token.encode()):
                abort(400, "Invalid CSRF token")

    @app.after_request
    def headers(response):
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "same-origin"
        static_url = urlsplit(os.environ.get("STATIC_BASE_URL", ""))
        static_origin = f"{static_url.scheme}://{static_url.netloc}" if static_url.netloc else ""
        response.headers["Content-Security-Policy"] = f"default-src 'self'; style-src 'self' {static_origin}; form-action 'self'; frame-ancestors 'none'; base-uri 'none'"
        if os.environ.get("LOCAL_DEVELOPMENT") != "1":
            response.headers["Strict-Transport-Security"] = "max-age=31536000"
        return response

    @app.get("/health")
    def health():
        return {"status": "alive"}

    @app.get("/ready")
    def ready():
        try:
            with db_factory(config_loader()) as conn:
                conn.execute("SELECT id FROM public.tasks LIMIT 1")
            return {"status": "ready"}
        except psycopg.Error:
            return {"status": "unavailable"}, 503

    @app.get("/")
    def index():
        session.setdefault("csrf_token", secrets.token_urlsafe(32))
        try:
            with db_factory(config_loader()) as conn:
                tasks = conn.execute("SELECT id, title, created_at FROM public.tasks ORDER BY id DESC LIMIT 50").fetchall()
        except psycopg.Error:
            app.logger.error("Database unavailable; request may be retried")
            return "Database temporarily unavailable. Please retry.", 503
        base = os.environ.get("STATIC_BASE_URL", "").rstrip("/")
        css = base + "/style.css" if base else url_for("static", filename="style.css")
        return render_template("index.html", tasks=tasks, css_url=css, csrf_token=session["csrf_token"])

    @app.post("/tasks")
    def add_task():
        title = request.form.get("title", "").strip()
        if not 1 <= len(title) <= 200:
            abort(400, "Title must contain 1 to 200 characters")
        try:
            with db_factory(config_loader()) as conn:
                conn.execute("INSERT INTO public.tasks (title) VALUES (%s)", (title,))
        except psycopg.Error:
            app.logger.error("Task write failed")
            return "Database temporarily unavailable. Please retry.", 503
        return redirect(url_for("index"), code=303)
    return app

# Tests set APP_TESTING=1 and call create_app with explicit fakes.
app = None if os.environ.get("APP_TESTING") == "1" else create_app()
