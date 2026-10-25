#!/usr/bin/env sh
# Removes the deployment's containers that have no network: a start that failed while setting up networking (e.g. a
# host port already taken) leaves its container created without one, and starting that container again later gives a
# service that can't reach the others (Nuxeo: "Failed to connect on database"). docker compose up then creates them
# again; volumes are kept. setup.sh runs it before starting (Windows: remove-detached.ps1).
#
#   sh scripts/remove-detached.sh
set -eu

here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

services="$(docker ps -a --filter label=com.docker.compose.project=kg-spaces \
  --format '{{.Label "com.docker.compose.service"}}|{{.Networks}}' | awk -F'|' '$2 == "" { print $1 }' | sort -u)"
if [ -n "$services" ]; then
  echo "Containers left without a network by an earlier failed start, removed (compose creates them again):" $services
  # shellcheck disable=SC2086
  docker compose -p kg-spaces rm -f -s $services
fi
