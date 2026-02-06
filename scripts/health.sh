#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "celery" ]]; then
  CELERY_APP="${CELERY_APP:-core}"
  CELERY_HEALTH_TIMEOUT="${CELERY_HEALTH_TIMEOUT:-5}"

  if [[ "${2:-}" == "beat" ]]; then
    if ! ps | grep -E "[c]elery .*beat" >/dev/null; then
      echo "Celery beat process not found"
      exit 1
    fi
  elif [[ "${2:-}" == "worker" ]]; then
    if ! ps | grep -E "[c]elery .*worker" >/dev/null; then
      echo "Celery worker process not found"
      exit 1
    fi
    celery -A "${CELERY_APP}" inspect ping -t "${CELERY_HEALTH_TIMEOUT}" >/dev/null
  else
    echo "Unknown celery role: ${2:-}"
    exit 1
  fi
elif [[ "${1:-}" == "server" ]]; then
  curl -sSf http://localhost:$PORT/healthcheck/ || exit 1
else
  echo "Unknown health check: $1, passing blindly"
  exit 0
fi
