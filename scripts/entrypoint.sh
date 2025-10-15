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
    exec gunicorn "${WSGI_MODULE}" -b 0.0.0.0:${PORT} ${GUNICORN_OPTS}
  fi
else
  exec "$@"
fi
