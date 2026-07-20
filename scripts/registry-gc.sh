#!/usr/bin/env bash
# Reclaims disk space for blobs orphaned by manifest deletions (e.g. the
# Jenkins "Prune Old Registry Tags" stage). Deleting a manifest only unlinks
# it -- the underlying blobs stay on disk until `registry garbage-collect`
# runs, and that command isn't safe to run against a writable, running
# registry (a concurrent push could reference a blob mid-GC). So this stops
# the container, runs GC against its data volume, then starts it back up.
#
# Intended to run from cron on the registry host during a low-traffic
# window, e.g.:
#   0 3 * * 0 REGISTRY_CONTAINER=registry /opt/scripts/registry-gc.sh
set -euo pipefail

REGISTRY_CONTAINER="${REGISTRY_CONTAINER:-registry}"
REGISTRY_CONFIG="${REGISTRY_CONFIG:-/etc/docker/registry/config.yml}"
LOG_FILE="${LOG_FILE:-/var/log/registry-gc.log}"

log() {
    echo "[$(date -Iseconds)] $*" >>"$LOG_FILE"
}

log "Starting registry GC (stopping ${REGISTRY_CONTAINER})"
docker stop "$REGISTRY_CONTAINER" >>"$LOG_FILE" 2>&1

docker run --rm \
    --volumes-from "$REGISTRY_CONTAINER" \
    -v "${REGISTRY_CONFIG}:${REGISTRY_CONFIG}:ro" \
    registry:2 \
    garbage-collect "$REGISTRY_CONFIG" >>"$LOG_FILE" 2>&1

log "GC complete, restarting ${REGISTRY_CONTAINER}"
docker start "$REGISTRY_CONTAINER" >>"$LOG_FILE" 2>&1

log "Done"
