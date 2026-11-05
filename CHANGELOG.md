# Changelog

All notable changes to KG Spaces Deployment are documented in this file. Versions follow the
[Flexible GraphRAG](https://github.com/stevereiner/flexible-graphrag) release whose images the
stack runs, with [KG Spaces ACA](https://github.com/stevereiner/kg-spaces-aca) and
[KG Spaces for Nuxeo](https://github.com/stevereiner/kg-spaces-nuxeo) at the same version.

## [2026-11-04] — v0.9.1: Flexible GraphRAG 0.9.1 and both KG Spaces apps at 0.9.1

### Changed

- **Version 0.9.1:** Flexible GraphRAG 0.9.1 images (backend, the three UIs, Langflow), and both
  KG Spaces apps built from their `v0.9.1` tags with `@flexible-graphrag/angular-ui` 0.9.1.
  - `.env`: `FLEXIBLE_GRAPHRAG_VERSION`, `KG_SPACES_ACA_GIT_REF`, `KG_SPACES_ACA_LIB_VERSION`,
    `KG_SPACES_NUXEO_GIT_REF`.
  - `flexible-graphrag/app-stack.override.yaml` and `langflow.override.yaml`: `0.9.1` image
    defaults.
  - The Flexible GraphRAG 0.9.1 backend brings security fixes (filesystem ingest limited to
    allowed folders, query injection fixes in several graph adapters and the RDF converter, graph
    Q&A runs only read queries; see its SECURITY.md) and faster KG extraction
    (`KG_EXTRACTION_WORKERS`).
- **`flexible-graphrag.env.sample`** refreshed from Flexible GraphRAG v0.9.1
  (`scripts/sync-flexible-graphrag.sh v0.9.1`): the OpenArch section now explains its two
  independent uses, `ENABLE_OPENARCH` (search + vector store) and
  `INCREMENTAL_STATE_STORE=openarch` (data sources and document state), with the 1024-dimension
  embedding lines to uncomment for OpenAI or Ollama.
- `scripts/sync-flexible-graphrag.sh`: usage examples name `v0.9.1`.
- README: Flexible GraphRAG 0.9.1 badge and versions, the sync example, and an updated screenshot
  (KG Spaces for Nuxeo's title bar, more data sources, CMIS sign-in in KG Spaces ACA).

## [2026-10-25] — v0.9.0: initial release

### Added

- **One Docker Compose stack** (`compose.yaml`, one file per component): Alfresco Community 26.2,
  Nuxeo LTS 2025 with Web UI, Hyland OpenArch, Flexible GraphRAG 0.9.0 (published images, its
  database menu, optional Langflow), KG Spaces ACA and KG Spaces for Nuxeo (built from their GitHub
  `v0.9.0` tags).
- **nginx proxy on 8080 with a landing page:** every app and repository on one address, so one
  sign-in to Alfresco and Nuxeo serves all; the page shows only the parts that run.
- **Hyland OpenArch in the default stack:** `INCREMENTAL_STATE_STORE=openarch` for data sources and
  document state, `ENABLE_OPENARCH=true` (with 1024-dimension embeddings) for search + vector
  storage, else Flexible GraphRAG's `VECTOR_DB` / `SEARCH_DB`.
- **`setup.sh` / `setup.bat [full|alfresco|nuxeo|none] [--sync] [--rebuild]`:** checks Docker and
  ports, sets which content repositories run here, syncs Flexible GraphRAG's files, makes
  `flexible-graphrag.env` from the sample and says what to set, builds the OpenArch image and KG
  Spaces for Nuxeo if missing, and starts the stack. Steps already done are skipped.
- **Content repositories here, outside, or none:** compose profiles `alfresco`, `nuxeo`,
  `kg-spaces-aca`, `kg-spaces-nuxeo` (`COMPOSE_PROFILES`, written by
  `scripts/set-repositories.sh` / `.ps1`); OpenArch, Flexible GraphRAG and the proxy always run.
  Outside repositories through `ALFRESCO_SERVER_URL`, `NUXEO_SERVER_URL` and related settings.
- **KG Spaces for Nuxeo:** the Web UI add-on installed into Nuxeo at every start (`nuxeo/addons/`),
  `kgspaces.url` from `KG_SPACES_NUXEO_URL`; Nuxeo waits for its database, search and Kafka at
  startup.
- **KG Spaces ACA:** built by compose from its GitHub tag, library from npm.
- **Development:** `FG_BACKEND_URL`, `FG_NUXEO_URL` and `KG_SPACES_NUXEO_URL` for a backend or app
  run from a checkout; local builds of Flexible GraphRAG (`build-flexible-graphrag.sh` / `.bat`)
  and both KG Spaces apps.
- **Scripts:** `sync-flexible-graphrag.sh` copies Flexible GraphRAG's Docker files, schemas, flows
  and settings sample from a release; `check-ports` lists other compose projects holding the
  deployment's ports; `remove-detached` removes containers a failed start left without a network.
- **Optional graph node storage** (prototype level, not the default): Nuxeo's documents
  (nuxeo-graph-storage) or OpenArch's repositories (openarch-graph-storage) in Neo4j or ArcadeDB.
- **Docs:** README (status, run steps, both KG Spaces apps, OpenArch settings, looking at OpenArch's
  data), `docs/env-setup.md`, `docs/graph-storage.md`.
