#!/bin/bash
# Installs this deployment's Nuxeo add-on bundles (nuxeo/addons/*.jar, mounted at /opt/kg-spaces/addons) at every
# Nuxeo start; run by the Nuxeo image's entrypoint from /docker-entrypoint-initnuxeo.d. Today: the KG Spaces for Nuxeo
# Web UI actions (scripts/build-kg-spaces-nuxeo.sh). An empty folder installs nothing.
#
# A jar named <name>-<version>.jar replaces any earlier <name>-*.jar, and add-ons removed from the folder since the
# last start are removed from Nuxeo (the list is kept in bundles/.kg-spaces-addons).
set -eu

src=/opt/kg-spaces/addons
bundles="${NUXEO_HOME:-/opt/nuxeo/server}/nxserver/bundles"
installed="$bundles/.kg-spaces-addons"

if [ -f "$installed" ]; then
  while read -r jar; do
    [ -n "$jar" ] && rm -f "$bundles/$jar"
  done < "$installed"
fi
: > "$installed"

for jar in "$src"/*.jar; do
  [ -e "$jar" ] || continue
  base="$(basename "$jar")"
  rm -f "$bundles/${base%-*}"-*.jar
  cp "$jar" "$bundles/$base"
  echo "$base" >> "$installed"
  echo "kg-spaces: installed Nuxeo add-on $base"
done

# Where the Web UI actions open KG Spaces for Nuxeo (the add-on's kgspaces.url). Absolute, through the proxy,
# so the actions work with Web UI on Nuxeo's own port too (a relative path would point at that port, where there is no
# app). Set on every start: nuxeo.conf outlives the container's first configure, when conf.d is read.
conf="${NUXEO_CONF:-/etc/nuxeo/nuxeo.conf}"
if [ -n "${KG_SPACES_NUXEO_URL:-}" ] && [ -w "$conf" ]; then
  kept="$(grep -v '^kgspaces\.url=' "$conf" || true)"
  printf '%s\nkgspaces.url=%s\n' "$kept" "$KG_SPACES_NUXEO_URL" > "$conf"
  echo "kg-spaces: kgspaces.url=$KG_SPACES_NUXEO_URL"
fi
