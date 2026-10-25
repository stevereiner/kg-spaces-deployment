#!/usr/bin/env sh
# Which content repositories run in this deployment: writes COMPOSE_PROFILES in .env, and stops the parts no longer
# wanted (setup.sh runs it; Windows: set-repositories.ps1).
#
#   sh scripts/set-repositories.sh [full|alfresco|nuxeo|none]      no argument: the ones COMPOSE_PROFILES has now
#
# A repository runs here with its profile (alfresco, nuxeo). Its KG Spaces app (kg-spaces-aca, kg-spaces-nuxeo) runs
# with it, or alone for one outside this deployment (ALFRESCO_SERVER_URL / NUXEO_SERVER_URL in .env). Optional
# profiles already in COMPOSE_PROFILES (langflow, debug, graph storage) are kept.
set -eu

here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here"
setting() { sed -n "s/^$1=//p" .env | tr -d '\r' | head -n 1 | sed 's/[[:space:]]*#.*//'; }
has() { case ",$1," in *",$2,"*) return 0 ;; *) return 1 ;; esac; }

old="$(setting COMPOSE_PROFILES)"
case "${1:-}" in
  full) alfresco=1; nuxeo=1 ;;
  alfresco) alfresco=1; nuxeo="" ;;
  nuxeo) alfresco=""; nuxeo=1 ;;
  none) alfresco=""; nuxeo="" ;;
  "") alfresco="$(has "$old" alfresco && echo 1 || true)"; nuxeo="$(has "$old" nuxeo && echo 1 || true)" ;;
  *) echo "unknown setup: $1 (use full, alfresco, nuxeo, none)" >&2; exit 2 ;;
esac

alfresco_url="$(setting ALFRESCO_SERVER_URL)"
nuxeo_url="$(setting NUXEO_SERVER_URL)"
if [ -n "$alfresco" ] && [ -n "$alfresco_url" ]; then
  echo "ALFRESCO_SERVER_URL is set in .env (an Alfresco outside this deployment): comment it out to run Alfresco here," >&2
  echo "or use setup nuxeo / none." >&2
  exit 1
fi
if [ -n "$nuxeo" ] && [ -n "$nuxeo_url" ]; then
  echo "NUXEO_SERVER_URL is set in .env (a Nuxeo outside this deployment): comment it out to run Nuxeo here, or use" >&2
  echo "setup alfresco / none." >&2
  exit 1
fi

new=""
add() { new="${new:+$new,}$1"; }
[ -n "$alfresco" ] && add alfresco
{ [ -n "$alfresco" ] || [ -n "$alfresco_url" ]; } && add kg-spaces-aca
[ -n "$nuxeo" ] && add nuxeo
{ [ -n "$nuxeo" ] || [ -n "$nuxeo_url" ]; } && add kg-spaces-nuxeo
for p in $(echo "$old" | tr ',' ' '); do
  case "$p" in alfresco|kg-spaces-aca|nuxeo|kg-spaces-nuxeo) ;; *) add "$p" ;; esac
done

if [ "$new" != "$old" ]; then
  if grep -q '^COMPOSE_PROFILES=' .env; then
    sed -i "s/^COMPOSE_PROFILES=.*/COMPOSE_PROFILES=$new/" .env
  else
    printf '\n# which parts run (setup.sh / setup.bat)\nCOMPOSE_PROFILES=%s\n' "$new" >> .env
  fi
  echo "COMPOSE_PROFILES=$new in .env (was ${old:-not set})"
  # stop the services of the profiles dropped
  for p in alfresco kg-spaces-aca nuxeo kg-spaces-nuxeo; do
    if has "$old" "$p" && ! has "$new" "$p"; then
      services="$(COMPOSE_PROFILES="$p" docker compose -p kg-spaces config --services 2>/dev/null | sort)"
      base="$(COMPOSE_PROFILES= docker compose -p kg-spaces config --services 2>/dev/null | sort)"
      only="$(printf '%s\n' "$services" | grep -vxF "$base" || true)"
      if [ -n "$only" ]; then
        # shellcheck disable=SC2086
        COMPOSE_PROFILES="$p" docker compose -p kg-spaces stop $only
      fi
    fi
  done
else
  echo "COMPOSE_PROFILES=$new"
fi
echo "Alfresco: $( [ -n "$alfresco" ] && echo "in this deployment" || { [ -n "$alfresco_url" ] && echo "outside it, $alfresco_url"; } || echo none)"
echo "Nuxeo: $( [ -n "$nuxeo" ] && echo "in this deployment" || { [ -n "$nuxeo_url" ] && echo "outside it, $nuxeo_url"; } || echo none)"
