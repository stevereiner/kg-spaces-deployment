#!/usr/bin/env sh
# Build OpenArch with its repositories on a graph database (openarch-graph-storage: Neo4j or ArcadeDB):
#
#   scripts/build-openarch-graph-storage.sh [<checkout folder>]
#
# From GitHub (stevereiner/openarch-graph-storage at OPENARCH_GRAPH_STORAGE_GIT_REF in .env), or from a local checkout;
# OpenArch itself at OPENARCH_GIT_REF in .env. Builds kg-spaces/openarch-graph-storage:<ref> (or :local). Then in .env:
#   OPENARCH_IMAGE=kg-spaces/openarch-graph-storage:<ref>
#   OPENARCH_GRAPH_BACKEND=neo4j            (or arcadedb)
#   COMPOSE_PROFILES=openarch-graph-neo4j   (or openarch-graph-arcadedb; comma-separated with other profiles)
set -eu

here="$(cd "$(dirname "$0")/.." && pwd)"
setting() { sed -n "s/^$1=//p" "$here/.env" | tr -d '\r'; }
openarch_ref="$(setting OPENARCH_GIT_REF)"
[ -n "$openarch_ref" ] || { echo "OPENARCH_GIT_REF is not set in .env" >&2; exit 2; }

if [ $# -gt 0 ] && [ -d "$1" ]; then
  context="$1"; tag=local; dockerfile="$1/docker/Dockerfile"
else
  ref="$(setting OPENARCH_GRAPH_STORAGE_GIT_REF)"
  [ -n "$ref" ] || { echo "OPENARCH_GRAPH_STORAGE_GIT_REF is not set in .env" >&2; exit 2; }
  context="https://github.com/stevereiner/openarch-graph-storage.git#$ref"; tag="$ref"; dockerfile=docker/Dockerfile
fi

docker build --build-arg "OPENARCH_GIT_REF=$openarch_ref" -f "$dockerfile" -t "kg-spaces/openarch-graph-storage:$tag" "$context"
echo "Built kg-spaces/openarch-graph-storage:$tag -- set OPENARCH_IMAGE=kg-spaces/openarch-graph-storage:$tag in .env"
