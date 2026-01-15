#!/usr/bin/env bash
set -euo pipefail

if [[ $1 == "celery" ]]; then
  pgrep -f 'celery.*worker' && pgrep -f 'celery.*beat' && celery -A core inspect ping -t 10 || exit 1
elif [ $1 == "server" ]; then
  curl -sSf http://localhost:$PORT/health/ || exit 1
else
  echo "Unknown health check: $1, passing blindly"
  exit 0
fi

