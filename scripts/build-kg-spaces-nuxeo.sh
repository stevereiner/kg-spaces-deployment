#!/usr/bin/env sh
# Build KG Spaces for Nuxeo: the app image (as compose does) and its Web UI add-on jar, into nuxeo/addons/ (all
# inside Docker: no JDK or Node needed on the host). Then restart Nuxeo to install the add-on:
#
#   scripts/build-kg-spaces-nuxeo.sh
#   docker compose -p kg-spaces up -d kg-spaces-nuxeo
#   docker compose -p kg-spaces restart nuxeo
#
# From GitHub at KG_SPACES_NUXEO_GIT_REF, or a local checkout at KG_SPACES_NUXEO_CONTEXT (both in .env).
set -eu

here="$(cd "$(dirname "$0")/.." && pwd)"
setting() { sed -n "s/^$1=//p" "$here/.env" | tr -d '\r'; }

context="$(setting KG_SPACES_NUXEO_CONTEXT)"
if [ -n "$context" ]; then
  case "$context" in /*|*://*) ;; *) context="$here/$context" ;; esac
  dockerfile="$context/docker/Dockerfile"   # a local context: the Dockerfile by its path
else
  ref="$(setting KG_SPACES_NUXEO_GIT_REF)"
  context="https://github.com/stevereiner/kg-spaces-nuxeo.git#${ref:-main}"
  dockerfile=docker/Dockerfile              # a Git context: relative to the repository
fi

mkdir -p "$here/nuxeo/addons"
rm -f "$here"/nuxeo/addons/kg-spaces-nuxeo-addon-*.jar
docker build -f "$dockerfile" --target addon --output "$here/nuxeo/addons" "$context"
(cd "$here" && docker compose -p kg-spaces build kg-spaces-nuxeo)
echo "Built the app image and $(ls "$here"/nuxeo/addons/*.jar) -- restart Nuxeo to install the add-on"
