#!/usr/bin/env sh
# Lists running containers of other stacks that hold host ports this deployment publishes, and exits 1 when there
# are any (setup.sh runs it before starting; Windows: check-ports.ps1). Other programs on those ports aren't seen.
#
#   sh scripts/check-ports.sh
set -eu

here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"

ports=" $(docker compose -p kg-spaces config 2>/dev/null | sed -n 's/^ *published: "\{0,1\}\([0-9][0-9]*\)"\{0,1\} *$/\1/p' | tr '\n' ' ')"
busy="$(docker ps --format '{{.Names}}|{{.Label "com.docker.compose.project"}}|{{.Ports}}' | awk -F'|' -v ports="$ports" '
  $2 != "kg-spaces" {
    n = split($3, published, ", ")
    for (i = 1; i <= n; i++) if (match(published[i], /:[0-9]+->/)) {
      p = substr(published[i], RSTART + 1, RLENGTH - 3)
      if (index(ports, " " p " ")) print "  " $1 " (" ($2 == "" ? "not from compose" : "compose project " $2) "): port " p
    }
  }' | sort -u)"

if [ -n "$busy" ]; then
  echo "Containers of other stacks hold ports this deployment uses:" >&2
  echo "$busy" >&2
  echo "Stop them first (docker compose -p <project> stop, or docker stop <container>), then run setup again." >&2
  exit 1
fi
echo "no other containers on the deployment's ports"
