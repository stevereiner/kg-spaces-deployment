#!/usr/bin/env sh
# Build OpenArch from its GitHub repository at a commit, for one newer than Hyland's published image
# (ghcr.io/hyland/openarch-app-jvm, OPENARCH_VERSION in .env):
#
#   scripts/build-openarch.sh [<commit or branch>]      default: OPENARCH_GIT_REF in .env
#
# Builds kg-spaces/openarch-all-mongodb:<ref> from openarch/Dockerfile (Maven inside Docker: no JDK, Maven or
# Hadoop tools needed on the host). Then in .env:
#   OPENARCH_IMAGE=kg-spaces/openarch-all-mongodb:<ref>
# and docker compose -p kg-spaces up -d openarch. The image runs as the same user as Hyland's, on the same volumes.
set -eu

here="$(cd "$(dirname "$0")/.." && pwd)"
ref="${1:-$(sed -n 's/^OPENARCH_GIT_REF=//p' "$here/.env" | tr -d '\r')}"
[ -n "$ref" ] || { echo "usage: scripts/build-openarch.sh <commit or branch> (or set OPENARCH_GIT_REF in .env)" >&2; exit 2; }

docker build --build-arg "OPENARCH_GIT_REF=$ref" -t "kg-spaces/openarch-all-mongodb:$ref" "$here/openarch"
echo "Built kg-spaces/openarch-all-mongodb:$ref -- set OPENARCH_IMAGE=kg-spaces/openarch-all-mongodb:$ref in .env"
