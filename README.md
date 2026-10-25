# KG Spaces Deployment

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Flexible GraphRAG](https://img.shields.io/badge/Flexible%20GraphRAG-0.9.0-2E7D32.svg)](https://github.com/stevereiner/flexible-graphrag)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![Supports Hyland OpenArch](https://img.shields.io/badge/Supports-Hyland%20OpenArch-0b5394.svg)](https://github.com/Hyland/OpenArch)

Docker Compose deployment of KG Spaces: [Flexible GraphRAG](https://github.com/stevereiner/flexible-graphrag)
with its UIs, [KG Spaces ACA](https://github.com/stevereiner/kg-spaces-aca),
[KG Spaces for Nuxeo](https://github.com/stevereiner/kg-spaces-nuxeo), the content repositories it ingests
from (Alfresco, Nuxeo) and [Hyland OpenArch](https://github.com/Hyland/OpenArch).

Five UIs: KG Spaces ACA, KG Spaces for Nuxeo, and Flexible GraphRAG's React, Vue and Angular UIs. All five search and
chat with the ingested content. The KG Spaces apps make choosing what to ingest easier: you pick files and folders in
the content repository's own file lists (Alfresco Content App, Nuxeo Web UI) and add them to KG Spaces, instead of
setting up a data source in a form.

Hyland OpenArch and Flexible GraphRAG always run; Alfresco and Nuxeo can run here, outside this deployment, or not at
all ([Content repositories](#content-repositories-here-outside-or-none)). Flexible GraphRAG uses OpenArch when set to
(two independent settings, [how they combine](#hyland-openarch-state-store-and-search--vector-store)):

- `INCREMENTAL_STATE_STORE=openarch` (in `.env`, the deployment's default): data sources and document state in
  OpenArch trees, in place of PostgreSQL;
- `ENABLE_OPENARCH=true` (in `flexible-graphrag.env`): search + vectors done by OpenArch (in its OpenSearch), fused with
  Flexible GraphRAG's property graph and / or RDF results, in place of Flexible GraphRAG's `SEARCH_DB` / `VECTOR_DB`.
  OpenArch currently indexes 1024-dimension vectors only: an embedding model that gives 1024 (e.g. Ollama's
  `mxbai-embed-large`) or can be set to 1024 (OpenAI's `text-embedding-3-small` / `-large` with
  `OPENAI_EMBEDDING_DIMENSION=1024`).

## KG Spaces projects

| Repo | Role |
|---|---|
| [flexible-graphrag](https://github.com/stevereiner/flexible-graphrag) | Flexible GraphRAG: the backend (ingest, auto sync, hybrid search, AI Q&A over property graph, RDF, vector and search databases), its React / Vue / Angular UIs, MCP server, and the shared Angular UI library ([`@flexible-graphrag/angular-ui`](https://www.npmjs.com/package/@flexible-graphrag/angular-ui)) the KG Spaces apps use |
| [kg-spaces-aca](https://github.com/stevereiner/kg-spaces-aca) | KG Spaces ACA: the Alfresco Content App with the KG Spaces extension |
| [kg-spaces-nuxeo](https://github.com/stevereiner/kg-spaces-nuxeo) | KG Spaces for Nuxeo: a KG Spaces menu in Nuxeo Web UI (add-on) and the app it opens |
| **[kg-spaces-deployment](https://github.com/stevereiner/kg-spaces-deployment)** | Docker Compose stack that wires everything together (this repo) |
| [python-openarch-api](https://github.com/stevereiner/python-openarch-api) | Python client for Hyland OpenArch's REST API, which Flexible GraphRAG uses for OpenArch |
| [Hyland/OpenArch](https://github.com/Hyland/OpenArch) | Hyland OpenArch, by Hyland: AI-ready content from all sources, with permissions (in the default stack) |
| [nuxeo-graph-storage](https://github.com/stevereiner/nuxeo-graph-storage) | builds this deployment's Nuxeo image (stock Nuxeo, documents in PostgreSQL, by default); optionally Nuxeo's documents in Neo4j or ArcadeDB (prototype) |
| [openarch-graph-storage](https://github.com/stevereiner/openarch-graph-storage) | optionally OpenArch's repositories in Neo4j or ArcadeDB (prototype) |
| [oak-graph-store](https://github.com/stevereiner/oak-graph-store) | the same for Apache Jackrabbit Oak (prototype; not part of this deployment) |

## Quick start

```bash
git clone https://github.com/stevereiner/kg-spaces-deployment.git
cd kg-spaces-deployment
sh setup.sh        # Windows, in PowerShell or Command Prompt: setup.bat
```

`setup.sh [full|alfresco|nuxeo|none] [--sync] [--rebuild]` (`setup.bat` the same) checks Docker, sets which content
repositories run here ([below](#content-repositories-here-outside-or-none); `full` the first time), runs the step
scripts in `scripts/` that are still needed and starts the stack (`docker compose -p kg-spaces up -d`). The first run
stops after making `flexible-graphrag.env`: set your LLM and embedding providers there, with their key if they need
one (`OPENAI_API_KEY` with the sample's OpenAI defaults; Ollama needs none), and optionally Hyland OpenArch as the
search + vector store (`ENABLE_OPENARCH=true` with a 1024-dimension embedding model, [above](#kg-spaces-deployment));
then run it again. Before starting, it lists containers of other stacks holding the deployment's ports
(`scripts/check-ports.sh` / `.ps1`), to stop first. Steps already done are skipped, so it can be run again any time.
`--sync` copies Flexible GraphRAG's files again (and its settings sample), `--rebuild` builds the images again.
Optional services (Langflow, debug tools, graph storage): `COMPOSE_PROFILES` in `.env`. The steps, to run them
yourself: [Run](#run).

## Content repositories: here, outside, or none

Hyland OpenArch, Flexible GraphRAG (backend and its three UIs) and the proxy always run. Alfresco and Nuxeo each run
in this deployment, outside it, or not at all; a repository's KG Spaces app runs whenever the repository is here or
outside:

| `setup` | Runs here | `COMPOSE_PROFILES` (in `.env`, written by setup) |
|---|---|---|
| `full` (the default in a fresh clone) | Alfresco + KG Spaces ACA, Nuxeo + KG Spaces for Nuxeo | `alfresco,kg-spaces-aca,nuxeo,kg-spaces-nuxeo` |
| `alfresco` | Alfresco + KG Spaces ACA | `alfresco,kg-spaces-aca` |
| `nuxeo` | Nuxeo + KG Spaces for Nuxeo | `nuxeo,kg-spaces-nuxeo` |
| `none` | neither: Flexible GraphRAG + OpenArch, with its other data sources (filesystem / upload, S3, SharePoint, web pages, ...) | (none of the four) |

Setup with no argument keeps the choice `.env` has. A change stops the containers of the parts left out (their
volumes stay, so switching back keeps their content); optional profiles in `COMPOSE_PROFILES` (`langflow`, `debug`,
graph storage) are kept. Plain `docker compose -p kg-spaces ...` commands follow `COMPOSE_PROFILES` too. The landing
page shows only the parts that run.

### Repositories outside this deployment

Set the repository's server address in `.env`, as the deployment's containers reach it, without `/alfresco` or
`/nuxeo` (one on this machine: `http://host.docker.internal:<port>`), and run setup without that repository (e.g.
`setup alfresco` with an outside Nuxeo, or `setup none` with both outside). The proxy's `/alfresco/` or `/nuxeo/`, the
backend and the KG Spaces app then use it.

| Setting (`.env`) | What |
|---|---|
| `ALFRESCO_SERVER_URL` | the outside Alfresco, e.g. `http://host.docker.internal:8180` |
| `ALFRESCO_STOMP_HOST`, `ALFRESCO_STOMP_PORT` | its ActiveMQ's STOMP, for Alfresco auto sync (with repository events on, as in Flexible GraphRAG's `alfresco.yaml`) |
| `ALFRESCO_ACA_URL` | where answers' and results' links open its documents (its Content App); by default this deployment's `/content-app`, which runs only with Alfresco here |
| `NUXEO_SERVER_URL` | the outside Nuxeo, e.g. `http://host.docker.internal:8180` |
| `NUXEO_KAFKA_BOOTSTRAP_SERVERS` | its Kafka, for Nuxeo auto sync (audit events to Kafka) |

KG Spaces for Nuxeo with an outside Nuxeo: Web UI's KG Spaces menu is an add-on in Nuxeo. Copy
`nuxeo/addons/kg-spaces-nuxeo-addon-*.jar` (built by setup) into that Nuxeo's `nxserver/bundles/`, add
`kgspaces.url=<KG_SPACES_NUXEO_URL>` (`http://localhost:8080/kg-spaces-nuxeo/` by default) to its `nuxeo.conf`, and
restart it. Open its Web UI through this deployment's proxy (`http://localhost:8080/nuxeo/ui/`): the app then shares the
Web UI sign-in, being on the same address. KG Spaces ACA needs nothing in Alfresco.

## Status

Version 0.9.0 (Flexible GraphRAG 0.9.0, KG Spaces ACA 0.9.0, KG Spaces for Nuxeo 0.9.0):

| Compose file | Component | State |
|---|---|---|
| [`compose.openarch.yaml`](compose.openarch.yaml) | OpenArch, stock: Hyland's published image (`ghcr.io/hyland/openarch-app-jvm`, `OPENARCH_VERSION`), or one built from source at any commit; all repositories in MongoDB (a one-member replica set, as in Hyland's own compose), search and vectors in OpenSearch | runs (1.0.44, and source at `661b3177`, `34caff31` and `28f4b833`); `.env` pins source at `28f4b833` |
| [`compose.alfresco.yaml`](compose.alfresco.yaml) | Alfresco Community 26.2: Flexible GraphRAG's own `alfresco.yaml` (all its settings: ActiveMQ with STOMP and repo events for auto sync, Keycloak identity service, AOS, Control Center, the stock Content App at `/content-app`, where answers' links open documents), routed by this deployment's nginx instead of Traefik, indexing into OpenArch's OpenSearch | runs |
| [`compose.proxy.yaml`](compose.proxy.yaml) | nginx proxy on 8080: Alfresco (`/alfresco`, `/share`), Nuxeo (`/nuxeo`), KG Spaces ACA (`/kg-spaces-aca`), KG Spaces for Nuxeo (`/kg-spaces-nuxeo`), Flexible GraphRAG's UIs (`/fg-react`, `/fg-vue`, `/fg-angular`, and their own `/ui/...`) and backend (`/fg-api`, and `/api`), and a landing page. The deployment's paths are settings in `.env` (`KG_SPACES_ACA_PATH`, `KG_SPACES_NUXEO_PATH`, `FG_REACT_PATH`, `FG_VUE_PATH`, `FG_ANGULAR_PATH`, `FG_API_PATH`), and so is the backend behind `/api` and `FG_API_PATH` (`FG_BACKEND_URL`: the deployment's container, or one running from a checkout on the host) | runs |
| [`compose.flexible-graphrag.yaml`](compose.flexible-graphrag.yaml) | Flexible GraphRAG 0.9.0: backend, React / Vue / Angular UIs (its own `app-stack.yaml` with published images), Langflow (`--profile langflow`), and any of the databases it supports from its own menu (`flexible-graphrag/docker/docker-compose.yaml`: by default Neo4j, ArcadeDB, Qdrant, Elasticsearch + Kibana, PostgreSQL); data sources and document state in PostgreSQL, or in Hyland OpenArch trees (`INCREMENTAL_STATE_STORE=openarch`); Hyland OpenArch as the search + vector store with `ENABLE_OPENARCH=true` | runs: 0.9.0 images with the databases menu (Neo4j, ArcadeDB, Qdrant, Elasticsearch, GraphDB) and with Hyland OpenArch as state store and search + vector store: ingest, auto sync, questions with sources |
| [`compose.kg-spaces-aca.yaml`](compose.kg-spaces-aca.yaml) | KG Spaces ACA: the Alfresco Content App with the KG Spaces extension, built from its GitHub repository at `KG_SPACES_ACA_GIT_REF` (with `@flexible-graphrag/angular-ui` from npm); served by the proxy at `/kg-spaces-aca/` and by its own nginx on port 4280 | runs (v0.9.0) |
| [`compose.kg-spaces-nuxeo.yaml`](compose.kg-spaces-nuxeo.yaml) | KG Spaces for Nuxeo: a KG Spaces menu in Web UI's document and selection toolbars (Add to KG Spaces; Ask KG Spaces about this document / folder), an add-on installed into Nuxeo at start from `nuxeo/addons/`, and the app they open, served by the proxy at `/kg-spaces-nuxeo/` and on port 4290; both built by `scripts/build-kg-spaces-nuxeo.sh` (the app image also by `docker compose ... --build`), from GitHub at `KG_SPACES_NUXEO_GIT_REF` or a checkout at `KG_SPACES_NUXEO_CONTEXT` ([below](#kg-spaces-for-nuxeo)) | runs (v0.9.0) |
| [`compose.nuxeo.yaml`](compose.nuxeo.yaml) | Nuxeo LTS 2025 with the Web UI, stock (documents in PostgreSQL), with OpenSearch 1.3 and Kafka (audit events, for Flexible GraphRAG's auto sync). Image built by [nuxeo-graph-storage](https://github.com/stevereiner/nuxeo-graph-storage)'s Dockerfile, from public source: despite the name, by default it is stock Nuxeo with documents in PostgreSQL (graph storage only with `NUXEO_TEMPLATES=graph-neo4j,...` or `graph-arcadedb,...`) | runs (tested with an image built from a nuxeo-graph-storage checkout) |
| [`compose.nuxeo.yaml`](compose.nuxeo.yaml), [`compose.openarch.yaml`](compose.openarch.yaml) | Graph storage (not the default: by default Nuxeo keeps its documents in PostgreSQL and OpenArch in MongoDB): Nuxeo's documents in Neo4j or ArcadeDB (nuxeo-graph-storage), OpenArch's repositories in Neo4j or ArcadeDB (openarch-graph-storage), each set up separately with its own database service ([docs/graph-storage.md](docs/graph-storage.md)) | prototype level; optional, not built or run by default |

Nothing is added to the content repositories: no custom aspect in Alfresco and no facet in Nuxeo. What is
ingested, and how, is kept by Flexible GraphRAG (in PostgreSQL or Hyland OpenArch), so it works the same for every source.

## Run

What `setup.sh` / `setup.bat` ([Quick start](#quick-start)) does, step by step:

```bash
sh scripts/set-repositories.sh full                     # or alfresco, nuxeo, none: COMPOSE_PROFILES in .env (above)
sh scripts/sync-flexible-graphrag.sh v0.9.0             # copies files from the Flexible GraphRAG v0.9.0 release (below)
cp flexible-graphrag.env.sample flexible-graphrag.env   # then set your LLM / embedding keys
sh scripts/build-openarch.sh                            # OpenArch at OPENARCH_GIT_REF, the image .env pins
sh scripts/build-kg-spaces-nuxeo.sh                     # KG Spaces for Nuxeo's app image, and its Web UI add-on jar into nuxeo/addons/
docker compose -p kg-spaces up -d --build
```

On Windows use the `.bat` scripts (`scripts\build-openarch.bat`, `scripts\build-kg-spaces-nuxeo.bat`).
`build-kg-spaces-nuxeo` puts the Web UI add-on jar in `nuxeo/addons/`, and Nuxeo installs it every time it starts
([KG Spaces for Nuxeo](#kg-spaces-for-nuxeo)); without the jar, Nuxeo starts without the KG Spaces menu.

In `flexible-graphrag.env`: the sample uses OpenAI for both the LLM and the embeddings, so set `OPENAI_API_KEY`, or
switch `LLM_PROVIDER` and `EMBEDDING_KIND` to another provider. For Hyland OpenArch as the search + vector store, add

```ini
ENABLE_OPENARCH=true
# OpenArch indexes 1024-dimension vectors only: text-embedding-3-* return that size when asked
OPENAI_EMBEDDING_DIMENSION=1024
```

(`INCREMENTAL_STATE_STORE` and `OPENARCH_URL` are set by the deployment: the first from `.env`, the second to the
OpenArch container.)

The sync script downloads the Flexible GraphRAG release you name (use the same version as `FLEXIBLE_GRAPHRAG_VERSION`
in `.env`) from GitHub and copies its database compose files (`docker/`: `docker-compose.yaml`, `includes/*.yaml` and
the folders they use) into `flexible-graphrag/docker/`, its `schemas/` and `flows/` into `flexible-graphrag/`, and its
`env-sample.txt` as `flexible-graphrag.env.sample`. Those files belong to Flexible GraphRAG's repository, so this one
doesn't keep them (they are gitignored here), except two of the deployment's own in `flexible-graphrag/docker/`: the
database menu `docker-compose.kg-spaces.yaml` and `.env`. It needs a POSIX shell (on Windows, Git Bash).

Flexible GraphRAG's databases: the menu (`flexible-graphrag/docker/docker-compose.kg-spaces.yaml`) says which run, and
`flexible-graphrag.env` which ones Flexible GraphRAG uses: `PG_GRAPH_DB` (property graph; the sample's default
`neo4j`, the menu also runs ArcadeDB), `RDF_GRAPH_DB` (RDF graph; the sample's default `none`), `VECTOR_DB`,
`SEARCH_DB` ([below](#flexible-graphrags-databases); each one's settings: Flexible GraphRAG's
[Databases](https://stevereiner.github.io/flexible-graphrag/HOME/HOME-DATABASES/) and
[Configuration](https://stevereiner.github.io/flexible-graphrag/HOME/HOME-CONFIGURATION/) documentation). For the RDF
graph, the menu starts Ontotext GraphDB, which needs your GraphDB license at
`flexible-graphrag/docker/ontotext-graphdb/GRAPHDB.license` (without it GraphDB fails every write and query). Without
a license, use another RDF store or none: in the menu, comment out `- includes/ontotext-graphdb.yaml` and uncomment
`- includes/jena-fuseki.yaml` or `- includes/oxigraph.yaml` (or neither), and in `flexible-graphrag.env` set
`RDF_GRAPH_DB=fuseki`, `oxigraph` or `none`.

Which settings go in which file (`.env`, `flexible-graphrag.env`, `flexible-graphrag/docker/.env`), and which wins:
[docs/env-setup.md](docs/env-setup.md). For Flexible GraphRAG's own settings (LLMs, databases, data sources), see
its [documentation](https://stevereiner.github.io/flexible-graphrag/): its `flexible-graphrag/.env` is
`flexible-graphrag.env` here.

The first build compiles Nuxeo with its Web UI (an hour or more). OpenArch: `.env` pins an image built from source at
commit `28f4b833` (`OPENARCH_GIT_REF`, `OPENARCH_IMAGE`; [OpenArch from source](#openarch-from-source)); comment out
`OPENARCH_IMAGE` to use Hyland's published image at `OPENARCH_VERSION` instead. To use
a Nuxeo image already built, set `NUXEO_IMAGE` (e.g. `nuxeo-graph-storage:local`) and start without `--build`. Settings -- versions, commits, host
ports -- are in [`.env`](.env). The deployment uses the usual ports (8080, 8081, 9200, 5432, ...), and Flexible GraphRAG's databases keep
theirs ([PORT-MAPPINGS.md](https://github.com/stevereiner/flexible-graphrag/blob/main/docs/ADVANCED/PORT-MAPPINGS.md)):
stop other stacks that use them first (stopped containers hold no ports). Flexible GraphRAG's database compose
files name their containers (`flexible-graphrag-neo4j`, ...): remove a Flexible GraphRAG dev stack's containers
(`docker compose -p <project> down`) before starting this one. The whole stack needs about 20 GB of memory for
Docker.

| Service | Address |
|---|---|
| Landing page (proxy) | http://localhost:8080 |
| Alfresco Share / Content App / repository / Control Center | http://localhost:8080/share, http://localhost:8080/content-app/, http://localhost:8080/alfresco, http://localhost:8080/admin (`admin` / `admin`) |
| Nuxeo Web UI | http://localhost:8081/nuxeo/ui, also http://localhost:8080/nuxeo/ui (`Administrator` / `Administrator`) |
| KG Spaces ACA | http://localhost:8080/kg-spaces-aca/, or on its own port http://localhost:4280 (`admin` / `admin`) |
| KG Spaces for Nuxeo | in Nuxeo Web UI, http://localhost:8080/nuxeo/ui or http://localhost:8081/nuxeo/ui: the KG Spaces menu's actions open http://localhost:8080/kg-spaces-nuxeo/ (same host, so the Web UI sign-in carries over); the app also on its own port, http://localhost:4290 |
| Flexible GraphRAG UIs | http://localhost:8080/fg-react/, `/fg-vue/`, `/fg-angular/` (also `/ui/react/`, `/ui/vue/`, `/ui/angular/`); or on their own ports: http://localhost:3000/ui/react/, http://localhost:5173/ui/vue/, http://localhost:4200/ui/angular/ |
| Flexible GraphRAG backend | http://localhost:8080/fg-api (also `/api`), API docs http://localhost:8080/fg-api/docs; or http://localhost:8000/api |
| Flexible GraphRAG's databases | as in Flexible GraphRAG: Neo4j http://localhost:7474 (`neo4j` / `password`), ArcadeDB http://localhost:2480 (`root` / `playwithdata`), Qdrant http://localhost:6333/dashboard, Elasticsearch http://localhost:9200, Kibana http://localhost:5601, PostgreSQL `localhost:5433` (`postgres` / `password`), pgAdmin http://localhost:5050, and those you enable |
| Langflow (`--profile langflow`) | http://localhost:7860 |
| OpenArch REST API | http://localhost:8088 (Swagger UI: `/swagger-ui/index.html`, `admin` / `password`) |
| OpenSearch (OpenArch's, shared with Alfresco) | http://localhost:9204; Dashboards http://localhost:5605 with `--profile debug` |
| Nuxeo's OpenSearch 1.3 | http://localhost:9205 |
| MongoDB (OpenArch) | `mongodb://localhost:27017` |
| Alfresco PostgreSQL | `localhost:5432` |
| ActiveMQ (Alfresco) | console http://localhost:8161 (`admin` / `admin`); STOMP 8613, OpenWire 8616 |
| Kafka (Nuxeo) | `localhost:9092`; Kafka UI http://localhost:8092 with `--profile debug` |

## Layout

`compose.yaml` is the only entrypoint: it includes one compose file per component. Run from this folder.

| Path | What |
|---|---|
| `setup.sh` / `setup.bat` | first run and later runs: checks Docker, runs the step scripts still needed, starts the stack ([Quick start](#quick-start)) |
| `compose.*.yaml` | one file per component: OpenArch, Alfresco, Nuxeo, Flexible GraphRAG, KG Spaces ACA, KG Spaces for Nuxeo, proxy |
| `openarch/` | the Dockerfile of an OpenArch image built from source (`scripts/build-openarch.sh`) |
| `alfresco/activemq.xml` | ActiveMQ's configuration with STOMP enabled |
| `proxy/` | nginx configuration and the landing page |
| `flexible-graphrag/` | the deployment's settings on top of Flexible GraphRAG's `app-stack.yaml` and `langflow.yaml` (`*.override.yaml`), the UIs' nginx configurations (with `/api`), and `schemas/` and `flows/` (mounted into the backend and Langflow) |
| `flexible-graphrag/docker/` | a copy of Flexible GraphRAG's `docker/` folder (same version as the images): `docker-compose.kg-spaces.yaml` is the deployment's database menu (ArcadeDB enabled; the release's own `docker-compose.yaml` sits next to it, to compare after a sync), `includes/` has the compose file of every database it supports, and `.env` is its `docker-env-sample.txt` with SCENARIO B on (service-name addresses) |
| `flexible-graphrag.env.sample` | Flexible GraphRAG's full settings sample: copy to `flexible-graphrag.env` |
| `scripts/sync-flexible-graphrag.sh <tag>` | refreshes `flexible-graphrag/docker/`, `schemas/`, `flows/` and the settings sample from a Flexible GraphRAG release (keeps the menu and `docker/.env`; `--keep-sample` leaves the settings sample as it is) |
| `scripts/build-flexible-graphrag.sh` / `.bat` | builds images from a Flexible GraphRAG checkout: the backend, with `--ui` the UIs, with `--langflow` Langflow, `--no-backend` to skip the backend; use them with `FLEXIBLE_GRAPHRAG_BACKEND_IMAGE` / `FLEXIBLE_GRAPHRAG_UI_*_IMAGE` / `FLEXIBLE_GRAPHRAG_LANGFLOW_IMAGE` in `.env` |
| `scripts/build-kg-spaces-nuxeo.sh` / `.bat` | builds KG Spaces for Nuxeo: its app image and its Web UI add-on jar (into `nuxeo/addons/`; restart Nuxeo to install it), from GitHub at `KG_SPACES_NUXEO_GIT_REF` or a checkout at `KG_SPACES_NUXEO_CONTEXT` |
| `nuxeo/` | `addons/`: Nuxeo add-on jars, installed at every Nuxeo start by `init/50-kg-spaces-addons.sh`, which also writes Nuxeo's `kgspaces.url` (where the Web UI actions open the app) from `KG_SPACES_NUXEO_URL` |
| `scripts/build-openarch.sh` / `.bat` | builds OpenArch from its GitHub repository at a commit (`OPENARCH_IMAGE`) |
| `scripts/set-repositories.sh` / `.ps1` | which content repositories run here (`full`, `alfresco`, `nuxeo`, `none`): writes `COMPOSE_PROFILES` in `.env` and stops the parts left out |
| `scripts/check-ports.sh` / `.ps1` | lists running containers of other stacks that hold host ports the deployment publishes (setup runs it before starting) |
| `scripts/remove-detached.sh` / `.ps1` | removes the deployment's containers an earlier failed start left without a network (e.g. on a port already taken), so `up` creates them again; volumes are kept (setup runs it before starting) |
| `scripts/build-openarch-graph-storage.sh` / `.bat` | builds OpenArch with its repositories on Neo4j or ArcadeDB, from openarch-graph-storage on GitHub or a checkout ([docs/graph-storage.md](docs/graph-storage.md)) |
| `docs/` | more detail on topics the README summarizes |

### Flexible GraphRAG's databases

1. Enable them in the deployment's menu, `flexible-graphrag/docker/docker-compose.kg-spaces.yaml` (comment include
   lines in or out, as in a Flexible GraphRAG checkout's `docker-compose.yaml`; the release's own
   `docker-compose.yaml` next to it is only there to compare with after a sync). Keep its `app-stack.yaml`, `proxy.yaml`, `langflow.yaml` and `alfresco*.yaml`
   lines commented: `compose.flexible-graphrag.yaml` includes the app and Langflow itself, and this deployment has
   its own proxy and Alfresco.
2. Pick them in `flexible-graphrag.env`: `PG_GRAPH_DB` (neo4j, arcadedb, falkordb, ...), `RDF_GRAPH_DB` (fuseki,
   graphdb, oxigraph), `VECTOR_DB`, `SEARCH_DB` (elasticsearch, opensearch, qdrant, ...). Their addresses are
   already in `flexible-graphrag/docker/.env`.
3. `docker compose -p kg-spaces up -d`.

### Hyland OpenArch: state store and search + vector store

Two independent settings. `ENABLE_OPENARCH=true` (in `flexible-graphrag.env`, from 0.9.0): Flexible GraphRAG writes
each document's text into OpenArch's `nuxeo` index and its chunks + embeddings into `nuxeo_embeddings`, and searches
them with OpenArch's hybrid query; its own `SEARCH_DB` / `VECTOR_DB` are not used. Don't point Flexible GraphRAG's own
OpenSearch store at OpenArch's OpenSearch: that would keep a second copy of the chunks there.
`INCREMENTAL_STATE_STORE=openarch` (in `.env`): data sources and document state in OpenArch trees instead of
PostgreSQL. Both need `ENABLE_INCREMENTAL_UPDATES=true` for data sources and auto sync, which the deployment sets.
Flexible GraphRAG's property graph and RDF databases (`PG_GRAPH_DB`, `RDF_GRAPH_DB`) are used the same way in all four:

| | `ENABLE_OPENARCH=false`: search + vectors by Flexible GraphRAG (its `SEARCH_DB` / `VECTOR_DB`) | `ENABLE_OPENARCH=true`: search + vectors by OpenArch (its OpenSearch), not Flexible GraphRAG's `SEARCH_DB` / `VECTOR_DB` |
|---|---|---|
| `INCREMENTAL_STATE_STORE=postgres` | data sources and document state in PostgreSQL; nothing in OpenArch | each document in OpenArch's tree with its text, chunks and embeddings; data sources and document state in PostgreSQL |
| `INCREMENTAL_STATE_STORE=openarch` | data sources and document state in OpenArch's tree (documents there without text or chunks) | all in OpenArch's tree: each document with its text, chunks, embeddings and state, and the data sources |

With `INCREMENTAL_STATE_STORE=openarch`, the settings made in the UIs' Processing rows (auto sync, graphs, search +
vectors) are kept per folder as well as per document, so new documents a sync finds under a folder follow that
folder's settings; with PostgreSQL they are kept per document, and a sync takes every new document.

To run Flexible GraphRAG code not released yet, build its images from a checkout and name them in `.env`:

```bash
scripts/build-flexible-graphrag.sh <checkout> --ui --langflow     # --no-backend: only the UI / Langflow images
# .env: FLEXIBLE_GRAPHRAG_BACKEND_IMAGE=kg-spaces/flexible-graphrag-backend:local (and the UI / Langflow images)
```

### Looking at OpenArch's data: MongoDB Compass and OpenSearch Dashboards

OpenArch keeps its documents in MongoDB, and its full-text and vector indexes in OpenSearch.

- **MongoDB Compass** (free, from MongoDB: [download](https://www.mongodb.com/try/download/compass), or on Windows
  `winget install MongoDB.Compass.Full`). Connect to `mongodb://localhost:27017/?directConnection=true`
  (`directConnection=true`: MongoDB runs as a one-member replica set that names itself by its container name, which
  your machine can't reach). Database `openarch`, collection `default`; documents use `sys_*` field names (parents by
  `sys_parentId`; the path itself is only in the search index). For example, filter
  `{ "sys_primaryType": "SysFile", "cin_sourceId": { "$exists": true } }` lists the documents Flexible GraphRAG wrote,
  with their source (`cin_id`, `cin_paths`), their state (`fg_docstate_*`) and, with `ENABLE_OPENARCH=true`, their
  text (`cin_ingestProperties.fg_extractedText`); `{ "sys_mixinTypes": "FgDataSource" }` lists the data sources. Look,
  don't edit: change things through Flexible GraphRAG.
- **OpenSearch Dashboards**: `docker compose -p kg-spaces --profile debug up -d openarch-search-dashboards`, then
  http://localhost:5605; in Dev Tools, `GET nuxeo_embeddings/_search` shows each chunk's text (`sysembed_text`) next
  to its vector.

### KG Spaces for Alfresco Content App (ACA)

[KG Spaces ACA](https://github.com/stevereiner/kg-spaces-aca) is the Alfresco Content App with the KG Spaces
extension: select files and folders in ACA's document lists and use **Add to KG Spaces** (or the toolbar's KG Spaces
menu, which also has **Ask KG Spaces about this document / folder**). It uses your ACA sign-in (Alfresco ticket), shows
**Alfresco · \<user\>** in its title bar with a sign-in pill for other sources, and opens Alfresco documents from
results and answers in ACA's own viewer. Compose builds its image from GitHub at `KG_SPACES_ACA_GIT_REF`, with
`@flexible-graphrag/angular-ui` from npm (`docker compose -p kg-spaces up -d --build`, or
`docker compose -p kg-spaces build kg-spaces-aca`).

Settings in `.env`:

| Setting | Default | What |
|---|---|---|
| `KG_SPACES_ACA_PATH` | `/kg-spaces-aca` | its path on the proxy |
| `KG_SPACES_ACA_PORT` | `4280` | its own port |
| `KG_SPACES_ACA_GIT_REF` | (set in `.env`, `v0.9.0`) | the kg-spaces-aca tag or commit built from GitHub |
| `KG_SPACES_ACA_LIB_VERSION` | `latest` | `@flexible-graphrag/angular-ui` version from npm |
| `KG_SPACES_ACA_CONTEXT` | (unset) | a local checkout to build instead, e.g. `../kg-spaces-aca` |
| `KG_SPACES_ACA_LIB_SOURCE` | `npm` | `local`: the library from a tarball in the checkout's `docker/lib/` (an unreleased library) |
| `KG_SPACES_ACA_IMAGE` | `kg-spaces/kg-spaces-aca:<git ref>` | the image's name |

### KG Spaces for Nuxeo

[KG Spaces for Nuxeo](https://github.com/stevereiner/kg-spaces-nuxeo) is two parts: a Nuxeo add-on with Web UI's
KG Spaces menu (a star graph icon; Add to KG Spaces, and Ask KG Spaces about this document / folder), and the app the
menu opens (Flexible GraphRAG's shared Angular UI, as in KG Spaces ACA).
`scripts/build-kg-spaces-nuxeo.sh` (Windows: `scripts\build-kg-spaces-nuxeo.bat`) builds both inside Docker: the
add-on jar into `nuxeo/addons/`, then the app image. Restart Nuxeo to install a new jar
(`docker compose -p kg-spaces restart nuxeo`); removing it from `nuxeo/addons/` uninstalls it at the next start.

The menu opens the app through the proxy, at `KG_SPACES_NUXEO_URL` (set in `compose.nuxeo.yaml` from
`KG_SPACES_HOST`, `PROXY_PORT` and `KG_SPACES_NUXEO_PATH`), which `nuxeo/init/50-kg-spaces-addons.sh` writes into
`nuxeo.conf` as `kgspaces.url` at every start. Being an absolute address, it works from Web UI on the proxy (8080) and
on Nuxeo's own port (8081): the browser sends the Nuxeo session cookie to any port of the same host, so there is no
second sign-in. The app keeps one browser tab (`kg-spaces-nuxeo`) and opens Nuxeo documents from results and answers
in Web UI's tab (`kg-spaces-nuxeo-web-ui`), so each is reused rather than opened again.

In the app, the title bar shows **Nuxeo · \<user\>** (the Web UI session: no sign-out there), a sign-in pill for the
other sources and servers in the stores, and a Dark / Light switch.

Settings in `.env`:

| Setting | Default | What |
|---|---|---|
| `KG_SPACES_NUXEO_PATH` | `/kg-spaces-nuxeo` | the app's path on the proxy |
| `KG_SPACES_NUXEO_PORT` | `4290` | the app's own port |
| `KG_SPACES_NUXEO_GIT_REF` | `main` (`.env` sets `v0.9.0`) | the kg-spaces-nuxeo tag, commit or branch built from GitHub |
| `KG_SPACES_NUXEO_URL` | the proxy's `KG_SPACES_NUXEO_PATH` | where Web UI's actions open the app (Nuxeo's `kgspaces.url`), e.g. `http://localhost:4300/kg-spaces-nuxeo/` for one run with `npm start`; recreate Nuxeo after a change |
| `KG_SPACES_NUXEO_CONTEXT` | (unset) | a local checkout to build instead, e.g. `../kg-spaces-nuxeo` |
| `KG_SPACES_NUXEO_IMAGE` | `kg-spaces/kg-spaces-nuxeo:<git ref>` | the app image's name |
| `FG_BACKEND_URL` | `http://flexible-graphrag-backend:8000` | the backend the proxy's `/api` (and `FG_API_PATH`) and the app's own port send to; `http://host.docker.internal:8000` for a backend running from a checkout on the host |
| `FG_NUXEO_URL` | `NUXEO_SERVER_URL` + `/nuxeo` (this deployment's Nuxeo: `http://nuxeo:8080/nuxeo`) | where that backend reaches Nuxeo (the app sends it in `nuxeo_config`): keep it the same as the backend's `NUXEO_URL`; `http://localhost:8081/nuxeo` for a backend on the host |

The deployment's backend (from 0.9.0) gets `NUXEO_WEBUI_URL` (`flexible-graphrag/app-stack.override.yaml`), so the
document links in results and answers open Web UI through the proxy. Whether an auto sync registered from the app
runs with the user's Nuxeo token or the backend's own Nuxeo account is Flexible GraphRAG's `NUXEO_SYNC_CREDENTIALS`
(from 0.9.0, in `flexible-graphrag.env`; default `token`, with the backend's account as the fallback when the token
stops working).

### Graph node storage for Nuxeo and/or OpenArch (optional, not the default)

Not the default: out of the box Nuxeo keeps its documents in PostgreSQL and OpenArch in MongoDB, and no graph database
service is built or started for them. Nuxeo and OpenArch can each keep their documents in a graph database, Neo4j or
ArcadeDB, instead, configured separately in `.env`, each with its own database service. Both
([nuxeo-graph-storage](https://github.com/stevereiner/nuxeo-graph-storage),
[openarch-graph-storage](https://github.com/stevereiner/openarch-graph-storage)) are at prototype level: for trying out,
not for content you need to keep. Choose before the repository's first
start. Steps, settings, checks and switching later: [docs/graph-storage.md](docs/graph-storage.md).

| | Nuxeo | OpenArch |
|---|---|---|
| Image | the same Nuxeo image | `scripts/build-openarch-graph-storage.sh`, then `OPENARCH_IMAGE` |
| Neo4j | `NUXEO_TEMPLATES=graph-neo4j,...`, profile `nuxeo-graph-neo4j` | `OPENARCH_GRAPH_BACKEND=neo4j`, profile `openarch-graph-neo4j` |
| ArcadeDB | `NUXEO_TEMPLATES=graph-arcadedb,...`, profile `nuxeo-graph-arcadedb` | `OPENARCH_GRAPH_BACKEND=arcadedb`, profile `openarch-graph-arcadedb` |

### OpenArch from source

Without `OPENARCH_IMAGE`, compose uses Hyland's published image at `OPENARCH_VERSION`; this repository's `.env` sets
`OPENARCH_IMAGE` to a build of commit `28f4b833` (`OPENARCH_GIT_REF`). For that or another commit of
[Hyland/OpenArch](https://github.com/Hyland/OpenArch), build one (Maven runs inside Docker: no JDK, Maven or Hadoop
tools needed on the host, Windows included):

```bash
scripts/build-openarch.sh [<commit or branch>]     # Windows: scripts\build-openarch.bat; default: OPENARCH_GIT_REF in .env
# .env: OPENARCH_IMAGE=kg-spaces/openarch-all-mongodb:<commit>
docker compose -p kg-spaces up -d openarch
```

It is configured the same way (`NUXEO_MONGODB_SERVER`, `OPENSEARCH_ADDRESSLIST`, ... in `compose.openarch.yaml`) and
runs as the same user as Hyland's image, so the two can be swapped on the same volumes. (Volumes from before the
published image was the default belong to another user: `docker run --rm -v kg-spaces_openarch-data:/d alpine chown
-R 33010:1000 /d` once.)

## License

[Apache License 2.0](LICENSE)
