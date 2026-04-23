#!/usr/bin/env bash
set -euo pipefail

if [[ "${ENABLED:-true}" == "false" ]]; then
  echo "Service disabled;"
  exec tail -f /dev/null
fi

# If first arg is "run", choose dev/prod command automatically; otherwise exec args
if [[ "${1:-run}" == "run" ]]; then
  if [[ "${COLLECTSTATIC}" == "true" ]]; then
      python manage.py collectstatic --noinput
  fi

  # Optional: wait for DB
  if [[ "${WAIT_FOR_DB}" == "true" ]]; then
    wait-for-db
  fi

  # Optional: Django admin steps (safe defaults are OFF)
  if [[ "${RUN_MIGRATIONS}" == "true" ]]; then
    python manage.py migrate --noinput
  fi

  if [[ "${DISABLE_GUNICORN:-false}" == "true" ]]; then
    exec python manage.py runserver "0.0.0.0:${PORT}"
  else
    gunicorn_config_file="${GUNICORN_CONFIG_FILE:-}"
    if [[ -z "$gunicorn_config_file" || ! -f "$gunicorn_config_file" ]]; then
      echo "Gunicorn config file not found at '${gunicorn_config_file}'" >&2
      exit 1
    fi
    exec gunicorn "${WSGI_MODULE}" -b "0.0.0.0:${PORT}" --config "$gunicorn_config_file"
  fi
elif [[ "${1:-}" == "celery" ]]; then
  if [[ "$2" == "beat" ]]; then
    exec celery -A core beat -l info
  elif [[ "$2" == "worker" ]]; then
    exec celery -A core worker --pool=gevent -c "${CELERY_CONCURRENCY:-20}" -l INFO
  fi
else
  exec "$@"
fi
