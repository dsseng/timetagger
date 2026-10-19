# syntax=docker/dockerfile:1
# Dockerfile to build an image from the repo.
# Note that the build context must be the root of the repo.
# Used by CI to build the image that is pushed to ghcr.
# Unpriviliged version that installs and runs as UID 1000.

FROM python:3.13.16-slim-trixie@sha256:70729b46c69b4f1e97c4822c1af3df53a1476cf5ddc6c087c0c10bc3a5678c2f AS builder

WORKDIR /build

COPY requirements.lock /build/
COPY vendor/ /build/vendor/

# Install pre-pulled wheels
RUN python -m pip install \
      --no-cache-dir \
      --no-index \
      --find-links=/build/vendor \
      --require-hashes \
      -r requirements.lock \
      --target /install/site-packages

COPY . /build/timetagger
RUN cd /build/timetagger && \
    python -m pip install \
      --no-cache-dir \
      --no-index \
      --find-links=/build/vendor \
      --no-deps \
      --target /install/site-packages \
      .

FROM python:3.13.16-slim-trixie@sha256:70729b46c69b4f1e97c4822c1af3df53a1476cf5ddc6c087c0c10bc3a5678c2f

# Create unpriviliged user and group, including directory structure
RUN groupadd -g 1000 timetagger && \
    useradd -r -u 1000 -m -g timetagger timetagger && \
    mkdir -p /opt/timetagger/data && \
    chown -R timetagger:timetagger /opt/timetagger

# Switch to unpriviliged user
USER 1000

WORKDIR /opt/timetagger
COPY --from=builder --chown=timetagger:timetagger /install/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=builder --chown=timetagger:timetagger /build/timetagger /opt/timetagger/app

ENV PYTHONPATH=/usr/local/lib/python3.13/site-packages:/opt/timetagger/app \
    TIMETAGGER_DATADIR=/opt/timetagger/data \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8080

CMD ["python", "-m", "timetagger"]
