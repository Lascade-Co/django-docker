# syntax=docker/dockerfile:1.9
FROM python:3.12-alpine AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    VIRTUAL_ENV=/opt/venv \
    PATH=/opt/venv/bin:$PATH \
    PORT=8000 \
    WSGI_MODULE=core.wsgi:application \
    WAIT_FOR_DB=false \
    RUN_MIGRATIONS=false \
    COLLECTSTATIC=false \
    GUNICORN_OPTS=""

# Runtime libs only (keep this lean)
RUN apk add --no-cache bash ca-certificates tzdata postgresql-libs curl

# Create venv once
RUN python -m venv $VIRTUAL_ENV

WORKDIR /opt
# Keep this minimal: only deps ALL services share
COPY requirements.txt base-requirements.txt
# Many libs now publish musllinux wheels; prefer binaries to avoid compiles
RUN --mount=type=cache,id=pip-base-alpine,target=/root/.cache/pip \
    pip install --upgrade pip && \
    pip install --prefer-binary --no-deps -r /opt/base-requirements.txt

# Common scripts (bash entrypoint + Python DB wait)
COPY scripts/wait-for-db.py /usr/local/bin/wait-for-db
COPY scripts/entrypoint.sh  /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/wait-for-db /usr/local/bin/entrypoint

# Non-root user
RUN adduser -S -u 10001 django
USER django
WORKDIR /usr/src/app

EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["run"]
