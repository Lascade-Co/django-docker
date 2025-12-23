# syntax=docker/dockerfile:1.9
FROM python:3.12-alpine AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PATH=/opt/venv/bin:$PATH \
    PORT=8000 \
    WSGI_MODULE=core.wsgi:application \
    WAIT_FOR_DB=true \
    RUN_MIGRATIONS=false \
    COLLECTSTATIC=false \
    GUNICORN_OPTS=""

# Runtime libs only (keep this lean)
RUN apk add --no-cache bash ca-certificates tzdata postgresql-libs curl

# Common scripts (bash entrypoint + Python DB wait)
COPY scripts/wait-for-db.py /usr/local/bin/wait-for-db
COPY scripts/entrypoint.sh  /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/wait-for-db /usr/local/bin/entrypoint

# Non-root user
RUN adduser -S -u 10001 django

# Create workdir with proper ownership before switching user
WORKDIR /usr/src/app
RUN chown -R 10001:65533 /usr/src/app && \
    chmod -R 755 /usr/src/app

USER django
ENV PATH="$PATH:/home/django/.local/bin"

# Keep this minimal: only deps ALL services share
COPY requirements.txt base-requirements.txt

# Many libs now publish musllinux wheels; prefer binaries to avoid compiles
RUN pip install --upgrade pip
RUN pip install --prefer-binary -r base-requirements.txt

EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/entrypoint"]
CMD ["run"]
