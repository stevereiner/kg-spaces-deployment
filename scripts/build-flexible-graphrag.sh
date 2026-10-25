#!/usr/bin/env sh
# Build Flexible GraphRAG images from a checkout, for code not released yet:
#
#   scripts/build-flexible-graphrag.sh <checkout> [--ui] [--langflow] [--no-backend]
#
# --no-backend: only the --ui / --langflow images (the backend image is not rebuilt)
#
#   kg-spaces/flexible-graphrag-backend:local      from <checkout>/flexible-graphrag
#   kg-spaces/flexible-graphrag-ui-<name>:local    with --ui: from <checkout>/flexible-graphrag-ui/frontend-<name>
#   kg-spaces/flexible-graphrag-langflow:local     with --langflow: <checkout>/flexible-graphrag/Dockerfile.langflow
#                                                  (Langflow with the backend's code, for --profile langflow)
#
# Then in .env: FLEXIBLE_GRAPHRAG_BACKEND_IMAGE=kg-spaces/flexible-graphrag-backend:local (and the UI and
# FLEXIBLE_GRAPHRAG_LANGFLOW_IMAGE images), and
#   docker compose -p kg-spaces up -d
# The checkout's .dockerignore keeps its .env and key files out of the image.
set -eu

src="${1:?usage: scripts/build-flexible-graphrag.sh <checkout> [--ui] [--langflow] [--no-backend]}"
shift
ui=""
langflow=""
backend=1
while [ $# -gt 0 ]; do
  case "$1" in
    --ui) ui=1 ;;
    --langflow) langflow=1 ;;
    --no-backend) backend="" ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done
tag="${FLEXIBLE_GRAPHRAG_LOCAL_TAG:-local}"

if [ -n "$backend" ]; then
  docker build -t "kg-spaces/flexible-graphrag-backend:$tag" "$src/flexible-graphrag"
fi
if [ -n "$ui" ]; then
  for name in angular react vue; do
    docker build -t "kg-spaces/flexible-graphrag-ui-$name:$tag" "$src/flexible-graphrag-ui/frontend-$name"
  done
fi
if [ -n "$langflow" ]; then
  docker build -f "$src/flexible-graphrag/Dockerfile.langflow" -t "kg-spaces/flexible-graphrag-langflow:$tag" \
    "$src/flexible-graphrag"
fi
echo "Built kg-spaces/flexible-graphrag-*:$tag from $src"
