#!/usr/bin/env bash
set -euo pipefail

if [[ $1 == "celery" ]]; then
  pgrep -f 'celery.*worker'
  pgrep -f 'celery.*beat'
  celery -A core status
elif [ $1 == "server" ]; then
  curl -sSf http://localhost:$PORT/healthcheck/ || exit 1
else
  echo "Unknown health check: $1, passing blindly"
  exit 0
fi
