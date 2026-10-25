# Settings files

The deployment's settings live in three files. They work in two different ways: Compose fills in the `${...}`
placeholders of the compose files from one set of files, and the Flexible GraphRAG backend container gets its
environment from another.

## Flexible GraphRAG's own documentation

Flexible GraphRAG documents its settings in full: [Flexible GraphRAG documentation](https://stevereiner.github.io/flexible-graphrag/).
Its pages name the files as they are in a Flexible GraphRAG checkout; in this deployment they are:

| In Flexible GraphRAG's docs | Here |
|---|---|
| `flexible-graphrag/.env` (from `env-sample.txt`) | `flexible-graphrag.env` (from `flexible-graphrag.env.sample`) |
| `docker/.env` (from `docker-env-sample.txt`) | `flexible-graphrag/docker/.env` |
| `docker/docker-compose.yaml`, `docker/includes/` | `flexible-graphrag/docker/docker-compose.kg-spaces.yaml` (the database menu: the deployment's copy of `docker-compose.yaml`, under its own name so a sync doesn't overwrite it), `flexible-graphrag/docker/includes/` |

Everything those pages say about the settings applies here, with the files renamed as above:

- [Environment configuration](https://stevereiner.github.io/flexible-graphrag/GETTING-STARTED/ENVIRONMENT-CONFIGURATION/):
  the settings in `.env`, i.e. `flexible-graphrag.env` here
- [Docker deployment](https://stevereiner.github.io/flexible-graphrag/GETTING-STARTED/DOCKER-DEPLOYMENT/): the database
  menu, `docker/.env` and its two scenarios (this deployment uses SCENARIO B, everything in Docker)
- [LLM and embedding configuration](https://stevereiner.github.io/flexible-graphrag/LLM/LLM-EMBEDDING-CONFIG/),
  [Ollama](https://stevereiner.github.io/flexible-graphrag/LLM/OLLAMA-CONFIGURATION/)
- [Database configuration](https://stevereiner.github.io/flexible-graphrag/DATABASES/DATABASE-CONFIGURATION/), and the
  [vector](https://stevereiner.github.io/flexible-graphrag/CONFIGURATION/CONFIG-VECTOR-DATABASES/),
  [search](https://stevereiner.github.io/flexible-graphrag/CONFIGURATION/CONFIG-SEARCH-DATABASES/) and
  [RDF](https://stevereiner.github.io/flexible-graphrag/CONFIGURATION/CONFIG-RDF-STORES/) store settings
- [Data source configuration](https://stevereiner.github.io/flexible-graphrag/DATA-SOURCES/DATA-SOURCE-CONFIGURATION/)
  and [auto sync](https://stevereiner.github.io/flexible-graphrag/DATA-SOURCES/INCREMENTAL-UPDATE-AUTO-SYNC/)
- [Port mappings](https://stevereiner.github.io/flexible-graphrag/ADVANCED/PORT-MAPPINGS/) (the database ports, the
  same here) and [Docker resource configuration](https://stevereiner.github.io/flexible-graphrag/ADVANCED/DOCKER-RESOURCE-CONFIGURATION/)
  (memory for Docker)

What this page adds is how the files fit together in this deployment, and what the deployment sets on top.

## The files

| File | What it holds | In git | Read by |
|---|---|---|---|
| `.env` (next to `compose.yaml`) | the deployment's settings: versions and commits, host ports, images, the proxy's paths and the backend behind it (`FG_BACKEND_URL`, `FG_NUXEO_URL`), `COMPOSE_PROFILES`, `NUXEO_TEMPLATES`, OpenArch storage, `INCREMENTAL_STATE_STORE` | yes | Compose, for the `${...}` in the deployment's compose files |
| `flexible-graphrag.env` | Flexible GraphRAG's own settings: LLM and embedding providers and keys, which databases it uses (`PG_GRAPH_DB`, `RDF_GRAPH_DB`, `VECTOR_DB`, `SEARCH_DB`), data source keys, feature flags. Copy it from `flexible-graphrag.env.sample` (Flexible GraphRAG's full `env-sample.txt`) | no (has your keys) | the backend and Langflow containers |
| `flexible-graphrag/docker/.env` | the databases' addresses inside this deployment (`NEO4J_GRAPH_DB_CONFIG` at `neo4j:7687`, `QDRANT_VECTOR_DB_CONFIG` at `qdrant:6333`, ...): Flexible GraphRAG's `docker-env-sample.txt` with its "SCENARIO B" lines on. Made by `scripts/sync-flexible-graphrag.sh` the first time, then kept | yes | the backend and Langflow containers; and Compose, for the few `${...}` in Flexible GraphRAG's database compose files |

`flexible-graphrag.env` can be somewhere else: set `FLEXIBLE_GRAPHRAG_ENV_FILE` in `.env` (or in your shell) to its
path, e.g. a Flexible GraphRAG checkout's `flexible-graphrag/.env`.

## Compose's `${...}` placeholders

Ports, image names and versions in the compose files are placeholders such as `${OPENARCH_PORT:-8088}` (the value after
`:-` is the default). Compose fills them from, highest priority first:

1. your shell's environment variables, e.g. `NUXEO_IMAGE=nuxeo-graph-storage:local docker compose -p kg-spaces up -d`
   (in PowerShell: `$env:NUXEO_IMAGE="..."` first)
2. `.env`
3. the default in the placeholder

Flexible GraphRAG's own database compose files (included from `flexible-graphrag/docker/docker-compose.kg-spaces.yaml`) take
their few placeholders (`ALFRESCO_SEARCH_HOST`, `VLLM_MODEL`, ...) from `flexible-graphrag/docker/.env` instead, as in a
Flexible GraphRAG checkout. `docker compose -p kg-spaces up -d --env-file other.env` uses `other.env` in place of `.env`
(the whole file, not just its differences).

`COMPOSE_PROFILES` in `.env` (comma-separated) turns on optional services: the graph databases of
[graph storage](graph-storage.md), `langflow`, `debug` (dashboards, Kafka UI).

## The backend container's environment

The backend (`flexible-graphrag-backend`) gets its variables from three layers; a later one overrides an earlier one
for the same variable:

1. **`flexible-graphrag.env`**: all of your Flexible GraphRAG settings.
2. **`flexible-graphrag/docker/.env`**: the databases' in-deployment addresses, so the `localhost` addresses a
   `flexible-graphrag.env` copied from a development setup may have don't matter.
3. **`environment:` in `flexible-graphrag/app-stack.override.yaml`** (on top of Flexible GraphRAG's `app-stack.yaml`):
   what is specific to this deployment: `ALFRESCO_URL`, `ALFRESCO_ACA_URL` (where the browser opens Alfresco documents),
   `ALFRESCO_STOMP_HOST` / `ALFRESCO_STOMP_PORT`, `CMIS_URL`, `NUXEO_URL`, `NUXEO_WEBUI_URL` (where the browser opens
   Nuxeo documents; from 0.9.0), `NUXEO_KAFKA_BOOTSTRAP_SERVERS`, `OPENARCH_URL`,
   `INCREMENTAL_STATE_STORE`, `ENABLE_INCREMENTAL_UPDATES`, and Langflow's URL. Several take their values from `.env`
   through placeholders (e.g. `INCREMENTAL_STATE_STORE: ${INCREMENTAL_STATE_STORE:-postgres}`).

So a setting in `flexible-graphrag.env` applies unless `flexible-graphrag/docker/.env` or the override sets the same
variable. Langflow (`--profile langflow`) gets layers 1 and 2 the same way (`flexible-graphrag/langflow.override.yaml`).
The UIs need no settings: their nginx forwards `/api` to the backend.

## Common changes

| To ... | Change | Where |
|---|---|---|
| use another LLM, embedding model or key | `LLM_PROVIDER`, `EMBEDDING_KIND`, ... | `flexible-graphrag.env` |
| use other Flexible GraphRAG databases | enable them in `flexible-graphrag/docker/docker-compose.kg-spaces.yaml`, then `PG_GRAPH_DB`, `VECTOR_DB`, ... | `flexible-graphrag.env` (addresses are already in `flexible-graphrag/docker/.env`) |
| move a host port | e.g. `OPENARCH_PORT`, `NUXEO_PORT`, `BACKEND_PORT` | `.env` |
| keep data source configs and document state in OpenArch | `INCREMENTAL_STATE_STORE=openarch` (backend 0.9.0 or later) | `.env` |
| run images you built | `FLEXIBLE_GRAPHRAG_BACKEND_IMAGE`, `FLEXIBLE_GRAPHRAG_UI_*_IMAGE`, `OPENARCH_IMAGE`, `NUXEO_IMAGE` | `.env` |
| put Nuxeo or OpenArch on a graph database | see [graph-storage.md](graph-storage.md) | `.env` |
| change Flexible GraphRAG's version | `FLEXIBLE_GRAPHRAG_VERSION`, then `scripts/sync-flexible-graphrag.sh v<version>` | `.env` |
| use a Flexible GraphRAG backend running from a checkout on the host (behind the proxy's `/api` and for KG Spaces for Nuxeo) | `FG_BACKEND_URL=http://host.docker.internal:8000`, and `FG_NUXEO_URL` set to that backend's `NUXEO_URL` (e.g. `http://localhost:8081/nuxeo`) | `.env` |
| build KG Spaces for Nuxeo from a checkout, or another commit | `KG_SPACES_NUXEO_CONTEXT` (e.g. `../kg-spaces-nuxeo`) or `KG_SPACES_NUXEO_GIT_REF`, then `scripts/build-kg-spaces-nuxeo.sh` | `.env` |
| use Hyland's published OpenArch image instead of the pinned build from source | comment out `OPENARCH_IMAGE` (then `OPENARCH_VERSION` applies) | `.env` |
| choose what a Nuxeo auto sync runs as | `NUXEO_SYNC_CREDENTIALS` (`token` or `account`; from 0.9.0) | `flexible-graphrag.env` |

## Applying a change

`docker compose -p kg-spaces up -d` recreates the services whose settings changed and leaves the others running; a
running container keeps the values it started with until then. If a change doesn't show, recreate that service:
`docker compose -p kg-spaces up -d --force-recreate flexible-graphrag-backend`.

To see what Compose will use, without starting anything: `docker compose -p kg-spaces config` (the whole resolved
configuration, including the backend's environment; it contains your keys, so don't paste it anywhere), or
`docker compose -p kg-spaces config --services` for the services the current profiles start.
