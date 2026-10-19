# Task board application

A small Flask application served by Gunicorn. Users can add and view tasks; PostgreSQL stores the records. Static CSS can be served locally or through the CloudFront URL configured by Terraform.

## Endpoints

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/` | Display the most recent 50 tasks; requires the demo login |
| POST | `/tasks` | Add a task; requires authentication and a valid CSRF token |
| GET | `/health` | Process liveness; used by the ALB target group |
| GET | `/ready` | Check access to the application database table |

`/health` and `/ready` are unauthenticated and return status only. A database outage causes readiness and database-dependent requests to return HTTP 503.

## Configuration

On EC2, the bootstrap script writes `/etc/webapp.env` and retrieves application credentials through the instance role. The service reads its secret from Secrets Manager and verifies the RDS TLS certificate.

`LOCAL_DEVELOPMENT=1` reads credentials from environment variables and disables database TLS and secure cookies. Use this mode only on a local development machine. Unit tests inject fake configuration and database connections, so they do not need this mode or a running PostgreSQL server.

## Test

From the repository root:

```bash
python -m pip install -r app/requirements.txt -r tests/requirements.txt
python -m pytest -q tests
```

The shared Basic Authentication login is intended for the sample. See [production hardening](../docs/SECURITY.md#production-hardening) before exposing real data.

## Database initialization

`init_db.py` creates the task table and restricted runtime role. Run it through Session Manager using the [deployment runbook](../docs/DEPLOYMENT.md#5-initialize-the-database-once), then remove the temporary administrator-secret permission. It is not a general schema migration tool.
