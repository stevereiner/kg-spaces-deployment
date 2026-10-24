# KG Spaces Deployment

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Flexible GraphRAG](https://img.shields.io/badge/Flexible%20GraphRAG-0.9.0-2E7D32.svg)](https://github.com/stevereiner/flexible-graphrag)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![Supports Hyland OpenArch](https://img.shields.io/badge/Supports-Hyland%20OpenArch-0b5394.svg)](https://github.com/Hyland/OpenArch)

Docker Compose deployment of KG Spaces: [Flexible GraphRAG](https://github.com/stevereiner/flexible-graphrag)
with its UIs, [KG Spaces ACA](https://github.com/stevereiner/kg-spaces-aca),
[KG Spaces for Nuxeo](https://github.com/stevereiner/kg-spaces-nuxeo), the content repositories it ingests
from (Alfresco, Nuxeo) and [Hyland OpenArch](https://github.com/Hyland/OpenArch).

Hyland OpenArch is in the default stack; Flexible GraphRAG uses it when set to:

- `INCREMENTAL_STATE_STORE=openarch` (in `.env`): data sources and document state in OpenArch trees, in place of
  PostgreSQL;
- `ENABLE_OPENARCH=true` (in `flexible-graphrag.env`, with `OPENAI_EMBEDDING_DIMENSION=1024`): OpenArch for search +
  vector storage and retrieval, fused with Flexible GraphRAG's property graph and / or RDF results. Otherwise
  Flexible GraphRAG's configured `VECTOR_DB` and `SEARCH_DB` are used.

## Status

Version 0.9.0 (Flexible GraphRAG 0.9.0, KG Spaces ACA 0.9.0, KG Spaces for Nuxeo 0.9.0):

| Component | Compose file | State |
|---|---|---|
| OpenArch, stock: Hyland's published image (`ghcr.io/hyland/openarch-app-jvm`, `OPENARCH_VERSION`), or one built from source at any commit; all repositories in MongoDB (a one-member replica set, as in Hyland's own compose), search and vectors in OpenSearch | [`compose.openarch.yaml`](compose.openarch.yaml) | runs (1.0.44, and source at `661b3177`, `34caff31` and `28f4b833`); `.env` pins source at `28f4b833` |
| Alfresco Community 26.2: Flexible GraphRAG's own `alfresco.yaml` (all its settings: ActiveMQ with STOMP and repo events for auto sync, Keycloak identity service, AOS, Control Center, the stock Content App at `/content-app`, where answers' links open documents), routed by this deployment's nginx instead of Traefik, indexing into OpenArch's OpenSearch | [`compose.alfresco.yaml`](compose.alfresco.yaml) | runs |
| nginx proxy on 8080: Alfresco (`/alfresco`, `/share`), Nuxeo (`/nuxeo`), KG Spaces ACA (`/kg-spaces-aca`), KG Spaces for Nuxeo (`/kg-spaces-nuxeo`), Flexible GraphRAG's UIs (`/fg-react`, `/fg-vue`, `/fg-angular`, and their own `/ui/...`) and backend (`/fg-api`, and `/api`), and a landing page. The deployment's paths are settings in `.env` (`KG_SPACES_ACA_PATH`, `KG_SPACES_NUXEO_PATH`, `FG_REACT_PATH`, `FG_VUE_PATH`, `FG_ANGULAR_PATH`, `FG_API_PATH`), and so is the backend behind `/api` and `FG_API_PATH` (`FG_BACKEND_URL`: the deployment's container, or one running from a checkout on the host) | [`compose.proxy.yaml`](compose.proxy.yaml) | runs |
| Flexible GraphRAG 0.9.0: backend, React / Vue / Angular UIs (its own `app-stack.yaml` with published images), Langflow (`--profile langflow`), and any of the databases it supports from its own menu (`flexible-graphrag/docker/docker-compose.yaml`: by default Neo4j, ArcadeDB, Qdrant, Elasticsearch + Kibana, PostgreSQL); data sources and document state in PostgreSQL, or in Hyland OpenArch trees (`INCREMENTAL_STATE_STORE=openarch`); Hyland OpenArch as the search + vector store with `ENABLE_OPENARCH=true` | [`compose.flexible-graphrag.yaml`](compose.flexible-graphrag.yaml) | runs: 0.9.0 images with the databases menu (Neo4j, ArcadeDB, Qdrant, Elasticsearch, GraphDB) and with Hyland OpenArch as state store and search + vector store: ingest, auto sync, questions with sources |
| KG Spaces ACA: the Alfresco Content App with the KG Spaces extension, built from its GitHub repository at `KG_SPACES_ACA_GIT_REF` (with `@flexible-graphrag/angular-ui` from npm); served by the proxy at `/kg-spaces-aca/` and by its own nginx on port 4280 | [`compose.kg-spaces-aca.yaml`](compose.kg-spaces-aca.yaml) | runs (v0.9.0) |
| KG Spaces for Nuxeo: a KG Spaces menu in Web UI's document and selection toolbars (Add to KG Spaces; Ask KG Spaces about this document / folder), an add-on installed into Nuxeo at start from `nuxeo/addons/`, and the app they open, served by the proxy at `/kg-spaces-nuxeo/` and on port 4290; both built by `scripts/build-kg-spaces-nuxeo.sh` (the app image also by `docker compose ... --build`), from GitHub at `KG_SPACES_NUXEO_GIT_REF` or a checkout at `KG_SPACES_NUXEO_CONTEXT` ([below](#kg-spaces-for-nuxeo)) | [`compose.kg-spaces-nuxeo.yaml`](compose.kg-spaces-nuxeo.yaml) | runs (v0.9.0) |
| Nuxeo LTS 2025 with the Web UI, stock (documents in PostgreSQL), with OpenSearch 1.3 and Kafka (audit events, for Flexible GraphRAG's auto sync). Image built by [nuxeo-graph-storage](https://github.com/stevereiner/nuxeo-graph-storage)'s Dockerfile, from public source | [`compose.nuxeo.yaml`](compose.nuxeo.yaml) | runs (tested with an image built from a nuxeo-graph-storage checkout) |
| Graph storage (optional, configured separately): Nuxeo's documents in Neo4j or ArcadeDB (nuxeo-graph-storage), OpenArch's repositories in Neo4j or ArcadeDB (openarch-graph-storage), each with its own database service ([docs/graph-storage.md](docs/graph-storage.md)) | [`compose.nuxeo.yaml`](compose.nuxeo.yaml), [`compose.openarch.yaml`](compose.openarch.yaml) | runs: all four combinations |

Planned:

| Component | Notes |
|---|---|
| Keycloak | one identity provider for the repositories, OpenArch, the backend and the UIs |
| scripts | Makefile and `setup.sh`, and `.bat` / PowerShell scripts for Windows |

Nothing is added to the content repositories: no custom aspect in Alfresco and no facet in Nuxeo. What is
ingested, and how, is kept by Flexible GraphRAG (in PostgreSQL or Hyland OpenArch), so it works the same for every source.

## Run

```bash
scripts/sync-flexible-graphrag.sh v0.9.0                # Flexible GraphRAG's docker files, schemas and flows (not in git)
cp flexible-graphrag.env.sample flexible-graphrag.env   # then set your LLM / embedding keys
scripts/build-openarch.sh                               # OpenArch at OPENARCH_GIT_REF, the image .env pins
scripts/build-kg-spaces-nuxeo.sh                        # KG Spaces for Nuxeo's app image and Web UI add-on jar
docker compose -p kg-spaces up -d --build
```

On Windows use the `.bat` scripts (`scripts\build-openarch.bat`, `scripts\build-kg-spaces-nuxeo.bat`). Without the
add-on jar in `nuxeo/addons/`, Nuxeo starts without the KG Spaces menu.

The sync script fetches the files of the Flexible GraphRAG release named by `FLEXIBLE_GRAPHRAG_VERSION` from GitHub:
`flexible-graphrag/docker/` (except the deployment's own database menu and `.env` there, which are in git),
`flexible-graphrag/schemas/` and `flexible-graphrag/flows/`. It needs a POSIX shell (on Windows, Git Bash). For Ontotext
GraphDB (enabled in the menu), put your GraphDB license at `flexible-graphrag/docker/ontotext-graphdb/GRAPHDB.license`
first: without it GraphDB fails every write and query.

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
| `compose.*.yaml` | one file per component: OpenArch, Alfresco, Nuxeo, Flexible GraphRAG, KG Spaces ACA, KG Spaces for Nuxeo, proxy |
| `openarch/` | the Dockerfile of an OpenArch image built from source (`scripts/build-openarch.sh`) |
| `alfresco/activemq.xml` | ActiveMQ's configuration with STOMP enabled |
| `proxy/` | nginx configuration and the landing page |
| `flexible-graphrag/` | the deployment's settings on top of Flexible GraphRAG's `app-stack.yaml` and `langflow.yaml` (`*.override.yaml`), the UIs' nginx configurations (with `/api`), `schemas/` and `flows/` (mounted into the backend and Langflow), and `Dockerfile.openarch-api` |
| `flexible-graphrag/docker/` | a copy of Flexible GraphRAG's `docker/` folder (same version as the images): `docker-compose.kg-spaces.yaml` is the deployment's database menu (ArcadeDB enabled; the release's own `docker-compose.yaml` sits next to it, to compare after a sync), `includes/` has the compose file of every database it supports, and `.env` is its `docker-env-sample.txt` with SCENARIO B on (service-name addresses) |
| `flexible-graphrag.env.sample` | Flexible GraphRAG's full settings sample: copy to `flexible-graphrag.env` |
| `scripts/sync-flexible-graphrag.sh <tag>` | refreshes `flexible-graphrag/docker/`, `schemas/`, `flows/` and the settings sample from a Flexible GraphRAG release (keeps the menu and `docker/.env`) |
| `scripts/build-flexible-graphrag.sh` / `.bat` | builds backend (and with `--ui` UI) images from a Flexible GraphRAG checkout, with `--openarch-api` adding python-openarch-api; use them with `FLEXIBLE_GRAPHRAG_BACKEND_IMAGE` / `FLEXIBLE_GRAPHRAG_UI_*_IMAGE` in `.env` |
| `scripts/build-kg-spaces-nuxeo.sh` / `.bat` | builds KG Spaces for Nuxeo: its app image and its Web UI add-on jar (into `nuxeo/addons/`; restart Nuxeo to install it), from GitHub at `KG_SPACES_NUXEO_GIT_REF` or a checkout at `KG_SPACES_NUXEO_CONTEXT` |
| `nuxeo/` | `addons/`: Nuxeo add-on jars, installed at every Nuxeo start by `init/50-kg-spaces-addons.sh`, which also writes Nuxeo's `kgspaces.url` (where the Web UI actions open the app) from `KG_SPACES_NUXEO_URL` |
| `scripts/build-openarch.sh` / `.bat` | builds OpenArch from its GitHub repository at a commit (`OPENARCH_IMAGE`) |
| `scripts/build-openarch-graph-storage.sh` / `.bat` | builds OpenArch with its repositories on Neo4j or ArcadeDB, from openarch-graph-storage on GitHub or a checkout ([docs/graph-storage.md](docs/graph-storage.md)) |
| `docs/` | more detail on topics the README summarizes |

### Flexible GraphRAG's databases

1. Enable them in `flexible-graphrag/docker/docker-compose.yaml` (comment include lines in or out, as in a
   Flexible GraphRAG checkout). Keep its `app-stack.yaml`, `proxy.yaml`, `langflow.yaml` and `alfresco*.yaml`
   lines commented: `compose.flexible-graphrag.yaml` includes the app and Langflow itself, and this deployment has
   its own proxy and Alfresco.
2. Pick them in `flexible-graphrag.env`: `PG_GRAPH_DB` (neo4j, arcadedb, falkordb, ...), `RDF_GRAPH_DB` (fuseki,
   graphdb, oxigraph), `VECTOR_DB`, `SEARCH_DB` (elasticsearch, opensearch, qdrant, ...). Their addresses are
   already in `flexible-graphrag/docker/.env`.
3. `docker compose -p kg-spaces up -d`.

Search and vectors in OpenArch instead of Flexible GraphRAG's own databases: `ENABLE_OPENARCH=true` (from 0.9.0;
embeddings must have 1024 dimensions, e.g. `text-embedding-3-small` with `dimensions=1024`). Flexible GraphRAG then
writes each document's text into OpenArch's `nuxeo` index and its chunks into `nuxeo_embeddings`, searches them with
OpenArch's hybrid query, and ignores `VECTOR_DB` / `SEARCH_DB`. Don't point Flexible GraphRAG's own OpenSearch store
at OpenArch's OpenSearch: that would keep a second copy of the chunks there.

Data sources and document state in the OpenArch tree (`INCREMENTAL_STATE_STORE=openarch` in `.env`) needs a
backend from 0.9.0 on; until then build one from a checkout:

```bash
scripts/build-flexible-graphrag.sh <checkout> --ui --openarch-api <python-openarch-api folder>
# .env: FLEXIBLE_GRAPHRAG_BACKEND_IMAGE=kg-spaces/flexible-graphrag-backend:local (and the UI images)
```

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
| `KG_SPACES_NUXEO_GIT_REF` | `main` | the kg-spaces-nuxeo commit or branch built from GitHub |
| `KG_SPACES_NUXEO_CONTEXT` | (unset) | a local checkout to build instead, e.g. `../kg-spaces-nuxeo` |
| `KG_SPACES_NUXEO_IMAGE` | `kg-spaces/kg-spaces-nuxeo:<git ref>` | the app image's name |
| `FG_BACKEND_URL` | `http://flexible-graphrag-backend:8000` | the backend the proxy's `/api` (and `FG_API_PATH`) and the app's own port send to; `http://host.docker.internal:8000` for a backend running from a checkout on the host |
| `FG_NUXEO_URL` | `http://nuxeo:8080/nuxeo` | where that backend reaches Nuxeo (the app sends it in `nuxeo_config`): keep it the same as the backend's `NUXEO_URL`; `http://localhost:8081/nuxeo` for a backend on the host |

The deployment's backend (from 0.9.0) gets `NUXEO_WEBUI_URL` (`flexible-graphrag/app-stack.override.yaml`), so the
document links in results and answers open Web UI through the proxy. Whether an auto sync registered from the app
runs with the user's Nuxeo token or the backend's own Nuxeo account is Flexible GraphRAG's `NUXEO_SYNC_CREDENTIALS`
(from 0.9.0, in `flexible-graphrag.env`; default `token`, with the backend's account as the fallback when the token
stops working).

### Graph storage for Nuxeo and OpenArch (optional)

Nuxeo and OpenArch can each keep their documents in a graph database, Neo4j or ArcadeDB, instead of PostgreSQL and
MongoDB, configured separately in `.env`, each with its own database service. Choose before the repository's first
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
