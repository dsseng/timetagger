# syntax=docker/dockerfile:1
# Dockerfile to build an image from the repo.
# Note that the build context must be the root of the repo.
# Used by CI to build the image that is pushed to ghcr.
# Unpriviliged version that installs and runs as UID 1000.

FROM python:3.13.16-slim-trixie@sha256:70729b46c69b4f1e97c4822c1af3df53a1476cf5ddc6c087c0c10bc3a5678c2f AS builder

WORKDIR /build

ARG SOURCE_DATE_EPOCH=0
ENV SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH} \
    PYTHONHASHSEED=0 \
    PYTHONDONTWRITEBYTECODE=1

COPY requirements.lock /build/
COPY vendor/ /build/vendor/

# Install pre-pulled wheels
RUN python -m pip install \
      --no-cache-dir \
      --no-index \
      --find-links=/build/vendor \
      --require-hashes \
      --no-compile \
      -r requirements.lock \
      --target /install/site-packages

COPY requirements.txt setup.py /build/timetagger/
COPY timetagger/ /build/timetagger/timetagger/
COPY contrib/ /build/timetagger/contrib/
RUN cd /build/timetagger && \
    python -m pip install \
      --no-cache-dir \
      --no-index \
      --find-links=/build/vendor \
      --no-deps \
      --target /install/site-packages \
      --no-compile \
      . && \
    rm -rf /build/timetagger/build /build/timetagger/*.egg-info

RUN python -m compileall -f -b --invalidation-mode=unchecked-hash /install/site-packages && \
    find /install/site-packages -exec touch -d "@${SOURCE_DATE_EPOCH}" {} + && \
    find /build/timetagger -exec touch -d "@${SOURCE_DATE_EPOCH}" {} +


FROM python:3.13.16-slim-trixie@sha256:70729b46c69b4f1e97c4822c1af3df53a1476cf5ddc6c087c0c10bc3a5678c2f

ARG SOURCE_DATE_EPOCH=0
ENV SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}

# Create unpriviliged user and group, including directory structure
RUN groupadd -g 1000 timetagger && \
    useradd -r -u 1000 -m -g timetagger timetagger && \
    mkdir -p /opt/timetagger/data && \
    chown -R timetagger:timetagger /opt/timetagger && \
    find /etc/passwd /etc/group /etc/shadow /etc/gshadow /home /opt /opt/timetagger -exec touch -d "@${SOURCE_DATE_EPOCH}" {} + && \
    touch -d "@${SOURCE_DATE_EPOCH}" /etc

WORKDIR /opt/timetagger
COPY --from=builder --chown=timetagger:timetagger /install/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=builder --chown=timetagger:timetagger /build/timetagger /opt/timetagger/app

RUN find /usr/local/lib/python3.13/site-packages -exec touch -d "@${SOURCE_DATE_EPOCH}" {} + && \
    find /opt /opt/timetagger -exec touch -d "@${SOURCE_DATE_EPOCH}" {} +

# Switch to unpriviliged user
USER 1000

ENV PYTHONPATH=/usr/local/lib/python3.13/site-packages:/opt/timetagger/app \
    TIMETAGGER_DATADIR=/opt/timetagger/data \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8080

CMD ["python", "-m", "timetagger"]
