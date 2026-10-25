#!/bin/bash
# Nuxeo's startup check of its backing services (PostgreSQL, OpenSearch, Kafka) retries instead of giving up at the
# first failure. Compose starts Nuxeo after them (depends_on ... service_healthy), but Docker Desktop, starting again
# after a reboot, restarts every container at once: Nuxeo then met a PostgreSQL still starting up, failed its check
# and stayed unhealthy. Off by default in Nuxeo; here 60 tries 5 s apart. Run by the Nuxeo image's entrypoint from
# /docker-entrypoint-initnuxeo.d at every start, like 50-kg-spaces-addons.sh (nuxeo.conf outlives the container's
# first configure, when conf.d is read).
set -eu

conf="${NUXEO_CONF:-/etc/nuxeo/nuxeo.conf}"
if [ -w "$conf" ]; then
  kept="$(grep -v '^nuxeo\.backing\.check\.retry\.' "$conf" || true)"
  printf '%s\nnuxeo.backing.check.retry.enabled=true\nnuxeo.backing.check.retry.maxRetries=60\nnuxeo.backing.check.retry.delayInMs=5000\n' \
    "$kept" > "$conf"
  echo "kg-spaces: Nuxeo retries its backing services at startup (60 x 5 s)"
fi
