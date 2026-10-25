#!/usr/bin/env sh
# Refresh this deployment's copy of Flexible GraphRAG's Docker files and settings sample from a release:
#   flexible-graphrag/docker/          <- docker/ (includes and the folders they use, and the release's
#                                         docker-compose.yaml), keeping this deployment's own files there:
#                                           docker-compose.kg-spaces.yaml  the database menu (not in the release, so
#                                                                          never overwritten; compare it with the
#                                                                          release's docker-compose.yaml after a sync)
#                                           .env                 the databases' addresses here (made once from
#                                                                docker-env-sample.txt with SCENARIO B on)
#                                         and your GraphDB license, ontotext-graphdb/GRAPHDB.license (not released)
#   flexible-graphrag/schemas/, flows/ <- schemas/, flows/ (mounted into the backend and Langflow)
#   flexible-graphrag.env.sample       <- flexible-graphrag/env-sample.txt, under this deployment's header
#
#   scripts/sync-flexible-graphrag.sh v0.9.0
#
# Downloads the tag's archive from GitHub (no checkout needed). Review the changes before committing, and set
# FLEXIBLE_GRAPHRAG_VERSION in .env to the same version.
set -eu

tag="${1:?usage: scripts/sync-flexible-graphrag.sh <tag, e.g. v0.9.0>}"
repo="${FLEXIBLE_GRAPHRAG_REPO:-stevereiner/flexible-graphrag}"
here="$(cd "$(dirname "$0")/.." && pwd)"
fg="$here/flexible-graphrag"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL "https://codeload.github.com/${repo}/tar.gz/refs/tags/${tag}" | tar -xz -C "$tmp"
src="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"

mkdir -p "$tmp/keep"
# the previous release's menu and Docker addresses sample, to tell whether this release changed them
for f in docker-compose.yaml docker-env-sample.txt; do
  if [ -f "$fg/docker/$f" ]; then cp "$fg/docker/$f" "$tmp/previous-$f"; fi
done
if [ -f "$here/flexible-graphrag.env.sample" ]; then cp "$here/flexible-graphrag.env.sample" "$tmp/previous-env.sample"; fi
for f in .env docker-compose.kg-spaces.yaml ontotext-graphdb/GRAPHDB.license; do
  if [ -f "$fg/docker/$f" ]; then mkdir -p "$(dirname "$tmp/keep/$f")"; cp "$fg/docker/$f" "$tmp/keep/$f"; fi
done
rm -rf "$fg/docker"
mkdir -p "$fg/docker"
cp -r "$src/docker/." "$fg/docker/"
find "$fg/docker" -name "*.bak" -delete

if [ -f "$tmp/keep/docker-compose.kg-spaces.yaml" ]; then
  cp "$tmp/keep/docker-compose.kg-spaces.yaml" "$fg/docker/docker-compose.kg-spaces.yaml"
  if [ -f "$tmp/previous-docker-compose.yaml" ] && ! cmp -s "$tmp/previous-docker-compose.yaml" "$fg/docker/docker-compose.yaml"; then
    echo "The release's flexible-graphrag/docker/docker-compose.yaml changed: compare it with docker-compose.kg-spaces.yaml"
  fi
else
  # first sync: the deployment's menu starts as the release's
  cp "$fg/docker/docker-compose.yaml" "$fg/docker/docker-compose.kg-spaces.yaml"
  echo "Made flexible-graphrag/docker/docker-compose.kg-spaces.yaml from the release's docker-compose.yaml: pick its databases there"
fi
if [ -f "$tmp/keep/.env" ]; then
  cp "$tmp/keep/.env" "$fg/docker/.env"
  if [ -f "$tmp/previous-docker-env-sample.txt" ] && ! cmp -s "$tmp/previous-docker-env-sample.txt" "$fg/docker/docker-env-sample.txt"; then
    echo "The release's flexible-graphrag/docker/docker-env-sample.txt changed: bring its new SCENARIO B addresses into flexible-graphrag/docker/.env (kept as it was)"
  fi
else
  # SCENARIO B on: each "# SCENARIO B...: #VAR=..." line becomes VAR=..., replacing VAR's SCENARIO A line
  awk '
    FNR == NR { if (match($0, /^# SCENARIO B[^:]*: #[A-Z0-9_]+=/)) { v = $0; sub(/^# SCENARIO B[^:]*: #/, "", v); sub(/=.*/, "", v); b[v] = 1 } next }
    FNR == 1 { print "# kg-spaces-deployment: docker-env-sample.txt with SCENARIO B (everything in Docker) on."; print "" }
    /^[A-Z0-9_]+=/ { v = $0; sub(/=.*/, "", v); if (v in b) { print "# SCENARIO A: #" $0; next } }
    /^# SCENARIO B[^:]*: #[A-Z0-9_]+=/ { sub(/^# SCENARIO B[^:]*: #/, ""); print; next }
    /^#VLLM_API_BASE=http:\/\/vllm:/ { sub(/^#/, ""); print; next }
    { print }
  ' "$fg/docker/docker-env-sample.txt" "$fg/docker/docker-env-sample.txt" > "$fg/docker/.env"
fi

if [ -f "$tmp/keep/ontotext-graphdb/GRAPHDB.license" ]; then
  mkdir -p "$fg/docker/ontotext-graphdb"
  cp "$tmp/keep/ontotext-graphdb/GRAPHDB.license" "$fg/docker/ontotext-graphdb/GRAPHDB.license"
fi

for d in schemas flows; do
  rm -rf "$fg/$d"
  if [ -d "$src/$d" ]; then cp -r "$src/$d" "$fg/$d"; fi
done

# keep this deployment's header (everything up to the first blank line after it), replace the rest
header="$(awk 'NR==1,/^$/' "$here/flexible-graphrag.env.sample" | sed "s/(v[0-9][0-9.]*, the version of the images/(${tag}, the version of the images/")"
{ printf '%s\n\n' "$header"; cat "$src/flexible-graphrag/env-sample.txt"; } > "$here/flexible-graphrag.env.sample"

# flexible-graphrag.env is yours: say when the settings sample it was copied from changed (beyond the header's version)
if [ -f "$tmp/previous-env.sample" ]; then
  awk 'body; /^$/ { body = 1 }' "$tmp/previous-env.sample" > "$tmp/previous-env.body"
  awk 'body; /^$/ { body = 1 }' "$here/flexible-graphrag.env.sample" > "$tmp/env.body"
fi
if [ -f "$tmp/previous-env.sample" ] && ! cmp -s "$tmp/previous-env.body" "$tmp/env.body"; then
  echo "flexible-graphrag.env.sample changed (git diff it): bring new or changed settings into flexible-graphrag.env"
fi

echo "Synced flexible-graphrag/docker, schemas, flows and flexible-graphrag.env.sample from ${repo} ${tag}"
