#!/usr/bin/env bash
set -euo pipefail

# If first arg is "run", choose dev/prod command automatically; otherwise exec args
if [[ "${1:-run}" == "run" ]]; then
  if [[ "${COLLECTSTATIC}" == "true" ]]; then
      python manage.py collectstatic --noinput
  fi

  # Optional: wait for DB
  if [[ "${WAIT_FOR_DB}" == "true" ]]; then
    /usr/local/bin/wait-for-db
  fi

  # Optional: Django admin steps (safe defaults are OFF)
  if [[ "${RUN_MIGRATIONS}" == "true" ]]; then
    python manage.py migrate --noinput
  fi

  if [[ "${DEBUG:-false}" == "true" ]]; then
    exec python manage.py runserver 0.0.0.0:${PORT}
  else
    # Default gunicorn logging options (safe, correctly quoted)
    DEFAULT_GUNICORN_OPTS=(
      --access-logfile gunicorn_access.log
      --error-logfile -
      --access-logformat '%(t)s pid=%(p)s %(h)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(L)s'
    )

    # Extra options from env (for simple flags like --workers 4)
    EXTRA_GUNICORN_OPTS=()
    if [[ -n "${GUNICORN_OPTS:-}" ]]; then
      # Intentional word splitting of GUNICORN_OPTS:
      # e.g. GUNICORN_OPTS="--workers 4 --timeout 60"
      # shellcheck disable=SC2206
      EXTRA_GUNICORN_OPTS=( ${GUNICORN_OPTS} )
    fi

    exec gunicorn "${WSGI_MODULE}" -b "0.0.0.0:${PORT}" \
      "${DEFAULT_GUNICORN_OPTS[@]}" \
      "${EXTRA_GUNICORN_OPTS[@]}"
  fi
else
  exec "$@"
fi
