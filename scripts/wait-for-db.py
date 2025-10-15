#!/usr/bin/env python3
"""
Wait for PostgreSQL to become reachable.

Env (preferred):
  POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
Optional:
  DATABASE_URL                # overrides the above if set (psycopg3 DSN)
  WAIT_TIMEOUT=60             # seconds
  WAIT_INTERVAL=1             # seconds between attempts
  WAIT_BACKOFF=false          # if "true", exponential backoff (caps at 5s)
  PGCONNECT_TIMEOUT=2         # per-try connect timeout in seconds
  PGSSLMODE                   # e.g., 'require', 'prefer', etc. (optional)

Exit codes:
  0   success
  124 timeout (nothing reachable within WAIT_TIMEOUT)
  2   misconfiguration (missing env)
  1   other error
"""

import os, sys, time, signal
from contextlib import closing

try:
    import psycopg
except Exception as e:
    print(f"[wait-for-db] ERROR: psycopg not available: {e}", file=sys.stderr)
    sys.exit(1)

_SHOULD_STOP = False
def _handle_term(signum, frame):
    global _SHOULD_STOP
    _SHOULD_STOP = True

signal.signal(signal.SIGINT, _handle_term)
signal.signal(signal.SIGTERM, _handle_term)

def getenv_bool(name: str, default: bool = False) -> bool:
    v = os.environ.get(name)
    if v is None:
        return default
    return v.lower() in ("1", "true", "yes", "on")

def build_dsn() -> str:
    # If DATABASE_URL is present, use it as-is.
    db_url = os.environ.get("DATABASE_URL")
    if db_url:
        return db_url

    # Otherwise compose from POSTGRES_* envs.
    host = os.environ.get("POSTGRES_HOST")
    port = os.environ.get("POSTGRES_PORT", "5432")
    db   = os.environ.get("POSTGRES_DB")
    user = os.environ.get("POSTGRES_USER")
    pwd  = os.environ.get("POSTGRES_PASSWORD")

    missing = [k for k, v in {
        "POSTGRES_HOST": host, "POSTGRES_DB": db,
        "POSTGRES_USER": user, "POSTGRES_PASSWORD": pwd
    }.items() if not v]
    if missing:
        print(f"[wait-for-db] ERROR: Missing required env: {', '.join(missing)}", file=sys.stderr)
        sys.exit(2)

    # Optional sslmode
    sslmode = os.environ.get("PGSSLMODE")
    ssl_part = f"?sslmode={sslmode}" if sslmode else ""

    return f"postgresql://{user}:{pwd}@{host}:{port}/{db}{ssl_part}"

def main() -> int:
    dsn = build_dsn()

    timeout_total = int(os.environ.get("WAIT_TIMEOUT", "60"))
    interval = float(os.environ.get("WAIT_INTERVAL", "1"))
    per_try = float(os.environ.get("PGCONNECT_TIMEOUT", "2"))
    backoff = getenv_bool("WAIT_BACKOFF", False)

    print(f"[wait-for-db] Waiting for PostgreSQL (timeout={timeout_total}s, interval={interval}s, per_try={per_try}s, backoff={backoff})")
    start = time.time()
    tries = 0
    current_interval = interval

    while True:
        if _SHOULD_STOP:
            print("[wait-for-db] Received termination signal; exiting.")
            return 143  # typical SIGTERM code

        elapsed = time.time() - start
        if elapsed >= timeout_total:
            print(f"[wait-for-db] Timeout after {timeout_total}s", file=sys.stderr)
            return 124

        tries += 1
        try:
            with closing(psycopg.connect(dsn, connect_timeout=per_try)) as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1;")
                    cur.fetchone()
            # Connected and query success.
            print(f"[wait-for-db] PostgreSQL is available after {tries} attempt(s), {elapsed:.2f}s.")
            return 0
        except Exception as e:
            # Common during startup; keep logs concise.
            print(f"[wait-for-db] Not ready (try {tries}): {e.__class__.__name__}", flush=True)
            # Sleep before next attempt
            time.sleep(current_interval)
            if backoff:
                current_interval = min(5.0, current_interval * 1.5)

if __name__ == "__main__":
    sys.exit(main())
