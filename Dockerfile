# syntax=docker/dockerfile:1.9
FROM python:3.12-alpine AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PORT=8000 \
    WSGI_MODULE=core.wsgi:application \
    WAIT_FOR_DB=true \
    RUN_MIGRATIONS=false \
    COLLECTSTATIC=true \
    GUNICORN_LOGS_FOLDER=/var/gunicorn \
    MEDIA_ROOT=/var/www/django/media \
    STATIC_ROOT=/var/www/django/static \
    GUNICORN_OPTS=""

# Runtime libs only (keep this lean)
RUN apk add --no-cache bash ca-certificates tzdata postgresql-libs curl postgresql-client postgis gdal

# Common scripts (bash entrypoint + Python DB wait)
COPY scripts/wait-for-db.py /usr/local/bin/wait-for-db
COPY scripts/entrypoint.sh  /usr/local/bin/entrypoint
COPY scripts/health.sh  /usr/local/bin/health

RUN chmod +x /usr/local/bin/wait-for-db /usr/local/bin/entrypoint /usr/local/bin/health

# Non-root user
RUN adduser -S -u 10001 django

RUN mkdir -p  "${GUNICORN_LOGS_FOLDER}" "${MEDIA_ROOT}" "${STATIC_ROOT}"
RUN chown -R django "${GUNICORN_LOGS_FOLDER}" "${MEDIA_ROOT}" "${STATIC_ROOT}"

USER django

WORKDIR /usr/src/app
ENV PATH="$PATH:/usr/local/bin:/home/django/.local/bin"

# Keep this minimal: only deps ALL services share
COPY requirements.txt base-requirements.txt
# Many libs now publish musllinux wheels; prefer binaries to avoid compiles
RUN pip install --upgrade pip
RUN pip install --prefer-binary -r base-requirements.txt

EXPOSE $PORT
ENTRYPOINT ["entrypoint"]
CMD ["run"]
