#!/usr/bin/env sh
# First run (and later runs) of the KG Spaces deployment: checks Docker, runs the step scripts in scripts/ that are
# still needed, and starts the stack. Steps already done are skipped, so it is safe to run again.
#
#   sh setup.sh [full|alfresco|nuxeo|none] [--sync] [--rebuild]
#
#   full | alfresco | nuxeo | none   the content repositories run in this deployment (default: as COMPOSE_PROFILES
#               in .env has them, full in a fresh clone); OpenArch and Flexible GraphRAG always run. A repository
#               outside this deployment: ALFRESCO_SERVER_URL / NUXEO_SERVER_URL in .env (its KG Spaces app runs here)
#   --sync      copy Flexible GraphRAG's files again (scripts/sync-flexible-graphrag.sh), even when present, and
#               its settings sample (flexible-graphrag.env.sample)
#   --rebuild   build the OpenArch and KG Spaces for Nuxeo images again, and start with --build
#
# Windows: setup.bat (PowerShell or Command Prompt). Optional services (langflow, debug, graph storage): COMPOSE_PROFILES
# in .env.
set -eu

here="$(cd "$(dirname "$0")" && pwd)"
cd "$here"
repositories=""
sync=""
rebuild=""
while [ $# -gt 0 ]; do
  case "$1" in
    full|alfresco|nuxeo|none) repositories="$1" ;;
    --sync) sync=1 ;;
    --rebuild) rebuild=1 ;;
    *) echo "unknown option: $1 (use full, alfresco, nuxeo, none, --sync, --rebuild)" >&2; exit 2 ;;
  esac
  shift
done

# the first uncommented NAME= line's value, without a trailing comment
setting() { sed -n "s/^$1=//p" "$2" | tr -d '\r' | head -n 1 | sed 's/[[:space:]]*#.*//'; }
step() { printf '\n%s\n' "$*"; }

step "1/7  Docker"
if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running: start Docker Desktop (or the Docker service) and run setup again." >&2
  exit 1
fi
docker compose version

step "2/7  Content repositories"
sh scripts/set-repositories.sh $repositories
profiles="$(setting COMPOSE_PROFILES .env)"
has() { case ",$profiles," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

step "3/7  Flexible GraphRAG's database compose files, schemas and flows"
version="$(setting FLEXIBLE_GRAPHRAG_VERSION .env)"
if [ -n "$sync" ]; then
  sh scripts/sync-flexible-graphrag.sh "v$version"
elif [ ! -d flexible-graphrag/docker/includes ] || [ ! -d flexible-graphrag/schemas ]; then
  # a fresh clone: the files git doesn't keep; the committed settings sample stays
  sh scripts/sync-flexible-graphrag.sh "v$version" --keep-sample
else
  echo "present (flexible-graphrag/docker/includes); --sync copies them again"
fi

step "4/7  flexible-graphrag.env"
state="$(setting INCREMENTAL_STATE_STORE .env)"
if [ ! -f flexible-graphrag.env ]; then
  cp flexible-graphrag.env.sample flexible-graphrag.env
  echo "Made flexible-graphrag.env from flexible-graphrag.env.sample. Set up in it, then run setup again:"
  echo "- your LLM and embedding providers (LLM_PROVIDER, EMBEDDING_KIND), and their key if they need one: the sample"
  echo "  uses OpenAI (OPENAI_API_KEY); Ollama needs no key"
  echo "- optionally Hyland OpenArch as the search + vector store: ENABLE_OPENARCH=true. OpenArch indexes 1024-dimension"
  echo "  vectors only: an embedding model that gives 1024 (e.g. Ollama's mxbai-embed-large) or can be set to 1024"
  echo "  (OpenAI's text-embedding-3-small / -large: OPENAI_EMBEDDING_DIMENSION=1024). Without it, Flexible GraphRAG's"
  echo "  VECTOR_DB and SEARCH_DB are used"
  if [ "$state" = openarch ]; then
    echo "Data sources and document state are kept in OpenArch trees (INCREMENTAL_STATE_STORE=openarch in .env;"
    echo "INCREMENTAL_STATE_STORE=postgres there keeps them in PostgreSQL)."
  else
    echo "Data sources and document state are kept in PostgreSQL (INCREMENTAL_STATE_STORE=openarch in .env keeps them"
    echo "in OpenArch trees)."
  fi
  exit 1
fi
llm="$(setting LLM_PROVIDER flexible-graphrag.env)"
embedding="$(setting EMBEDDING_KIND flexible-graphrag.env)"
key="$(setting OPENAI_API_KEY flexible-graphrag.env)"
openarch="$(setting ENABLE_OPENARCH flexible-graphrag.env)"
if { [ "$llm" = openai ] || [ "$embedding" = openai ]; } && { [ -z "$key" ] || [ "$key" = your-openai-api-key-here ]; }; then
  echo "flexible-graphrag.env uses OpenAI (LLM_PROVIDER / EMBEDDING_KIND) but OPENAI_API_KEY is not set: set it, or" >&2
  echo "switch to a provider that needs no key (e.g. ollama), then run setup again." >&2
  exit 1
fi
if [ "$openarch" = true ]; then
  if [ "$embedding" = openai ]; then
    dimension="$(setting OPENAI_EMBEDDING_DIMENSION flexible-graphrag.env)"
    if [ "$dimension" != 1024 ]; then
      echo "ENABLE_OPENARCH=true: OpenArch indexes 1024-dimension vectors only; set OPENAI_EMBEDDING_DIMENSION=1024" >&2
      echo "(now ${dimension:-not set}) in flexible-graphrag.env, then run setup again." >&2
      exit 1
    fi
  else
    echo "Note: ENABLE_OPENARCH=true: OpenArch indexes 1024-dimension vectors only; EMBEDDING_KIND=$embedding must give 1024."
  fi
fi
if [ "$(setting RDF_GRAPH_DB flexible-graphrag.env)" = graphdb ] && [ ! -f flexible-graphrag/docker/ontotext-graphdb/GRAPHDB.license ]; then
  echo "Note: RDF_GRAPH_DB=graphdb without flexible-graphrag/docker/ontotext-graphdb/GRAPHDB.license: GraphDB fails"
  echo "every write and query (README: RDF graph database)."
fi
echo "ok (LLM_PROVIDER=$llm, EMBEDDING_KIND=$embedding, ENABLE_OPENARCH=${openarch:-false}; .env: INCREMENTAL_STATE_STORE=${state:-postgres})"

step "5/7  OpenArch image"
image="$(setting OPENARCH_IMAGE .env)"
ref="$(setting OPENARCH_GIT_REF .env)"
if [ -z "$image" ]; then
  echo "Hyland's published image, OPENARCH_VERSION=$(setting OPENARCH_VERSION .env) (pulled at start)"
elif [ -z "$rebuild" ] && docker image inspect "$image" >/dev/null 2>&1; then
  echo "present: $image"
elif [ "$image" = "kg-spaces/openarch-all-mongodb:$ref" ]; then
  sh scripts/build-openarch.sh "$ref"
else
  echo "OPENARCH_IMAGE=$image is not built: build it with scripts/build-openarch-graph-storage.sh" >&2
  echo "(docs/graph-storage.md), or comment it out in .env for Hyland's published image." >&2
  exit 1
fi

step "6/7  KG Spaces for Nuxeo: Web UI add-on and app image"
if ! has kg-spaces-nuxeo; then
  echo "not used (no Nuxeo here or NUXEO_SERVER_URL)"
elif [ -z "$rebuild" ] && ls nuxeo/addons/kg-spaces-nuxeo-addon-*.jar >/dev/null 2>&1; then
  echo "present: $(ls nuxeo/addons/kg-spaces-nuxeo-addon-*.jar)"
else
  sh scripts/build-kg-spaces-nuxeo.sh
fi
if has kg-spaces-nuxeo && ! has nuxeo; then
  echo "Nuxeo outside this deployment: install the add-on there for Web UI's KG Spaces menu (copy"
  echo "nuxeo/addons/kg-spaces-nuxeo-addon-*.jar into its nxserver/bundles/, add"
  echo "kgspaces.url=$(setting KG_SPACES_NUXEO_URL .env) to its nuxeo.conf, restart it), and open its Web UI through"
  echo "this deployment's proxy (/nuxeo/ui/), so the app shares the sign-in (README: Repositories outside this deployment)."
fi

step "7/7  Starting the stack"
sh scripts/check-ports.sh
sh scripts/remove-detached.sh
if has nuxeo || has kg-spaces-aca; then
  echo "The first start builds the images still missing ($(has nuxeo && echo "Nuxeo with its Web UI: an hour or more; ")$(has kg-spaces-aca && echo "KG Spaces ACA: a few minutes")). Later starts are quick."
fi
if [ -n "$rebuild" ]; then
  docker compose -p kg-spaces up -d --build
else
  docker compose -p kg-spaces up -d
fi

port="$(setting PROXY_PORT .env)"
host="$(setting KG_SPACES_HOST .env)"
echo
echo "Started. Landing page: http://${host:-localhost}:${port:-8080} (links to every app)."
echo "Status: docker compose -p kg-spaces ps    Logs: docker compose -p kg-spaces logs -f <service>"
