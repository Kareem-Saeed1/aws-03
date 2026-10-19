"""Run once with temporary admin-secret permission, then revoke that permission."""
import json
import os
import boto3
import psycopg
from psycopg import sql

def main():
    client = boto3.client("secretsmanager")
    admin = json.loads(client.get_secret_value(SecretId=os.environ["ADMIN_SECRET_ARN"])["SecretString"])
    runtime = json.loads(client.get_secret_value(SecretId=os.environ["APP_SECRET_ARN"])["SecretString"])
    with psycopg.connect(host=os.environ["DB_HOST"], dbname=os.environ["DB_NAME"],
                         user=admin["username"], password=admin["password"],
                         sslmode="verify-full", sslrootcert=os.environ["DB_SSLROOTCERT"],
                         connect_timeout=10) as conn:
        conn.execute("SELECT pg_advisory_xact_lock(620184)")
        role = sql.Identifier(runtime["db_username"])
        if not conn.execute("SELECT 1 FROM pg_roles WHERE rolname = %s", (runtime["db_username"],)).fetchone():
            conn.execute(sql.SQL("CREATE ROLE {} LOGIN").format(role))
        conn.execute(sql.SQL("ALTER ROLE {} WITH PASSWORD {} NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION").format(role, sql.Literal(runtime["db_password"])))
        conn.execute("REVOKE CREATE ON SCHEMA public FROM PUBLIC")
        conn.execute("CREATE TABLE IF NOT EXISTS public.tasks (id BIGSERIAL PRIMARY KEY, title VARCHAR(200) NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT NOW())")
        conn.execute(sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(sql.Identifier(os.environ["DB_NAME"]), role))
        conn.execute(sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(role))
        conn.execute(sql.SQL("GRANT SELECT, INSERT ON TABLE public.tasks TO {}").format(role))
        conn.execute(sql.SQL("GRANT USAGE, SELECT ON SEQUENCE public.tasks_id_seq TO {}").format(role))
    print("Database initialized. Disable enable_db_bootstrap and apply Terraform now.")

if __name__ == "__main__":
    main()
