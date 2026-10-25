# Graph storage for Nuxeo and OpenArch

By default Nuxeo keeps its documents in PostgreSQL and OpenArch keeps its repositories in MongoDB. Either one, or both,
can keep them in a graph database instead, Neo4j or ArcadeDB, using
[nuxeo-graph-storage](https://github.com/stevereiner/nuxeo-graph-storage) and
[openarch-graph-storage](https://github.com/stevereiner/openarch-graph-storage). The two are configured separately in
`.env`, and each gets its own graph database service in this deployment, not Flexible GraphRAG's Neo4j or ArcadeDB.

Both are at prototype level: for trying out, not for content you need to keep.

What stays where it was: Nuxeo still uses its PostgreSQL (users and groups, directories, audit), its OpenSearch and
Kafka. OpenArch still uses MongoDB (key/value store, scheduler, configuration documents) and its OpenSearch.

## Ports

No ports move. Each graph database service gets its own host ports, the ones nuxeo-graph-storage and
openarch-graph-storage use in their own stacks, clear of everything else in this deployment (Flexible GraphRAG's Neo4j
is on 7474 / 7687 and its ArcadeDB on 2480 / 7689):

| Service | Host ports | `.env` settings |
|---|---|---|
| `nuxeo-neo4j` | 7476 (Browser), 7691 (Bolt) | `NUXEO_NEO4J_HTTP_PORT`, `NUXEO_NEO4J_BOLT_PORT` |
| `nuxeo-arcadedb` | 2491 (Studio, HTTP) | `NUXEO_ARCADEDB_HTTP_PORT` |
| `openarch-neo4j` | 7477 (Browser), 7692 (Bolt) | `OPENARCH_NEO4J_HTTP_PORT`, `OPENARCH_NEO4J_BOLT_PORT` |
| `openarch-arcadedb` | 2492 (Studio, HTTP) | `OPENARCH_ARCADEDB_HTTP_PORT` |

They're only taken while that profile is on. If you also run nuxeo-graph-storage's or openarch-graph-storage's own
stacks, stop them first: they use the same ports.

## Choose before the first start

A graph-backed repository is a new, empty one. Switching an existing repository leaves its documents in the old store,
and the repository's search index would then hold documents of both. Set the storage in `.env` before the first
`docker compose up`, or start that component on fresh volumes (see [Switching later](#switching-later)).

## Nuxeo

Nothing to build: the deployment's Nuxeo image (built by nuxeo-graph-storage's Dockerfile) contains both graph backends.
In `.env`:

| Graph database | `NUXEO_TEMPLATES` | Add to `COMPOSE_PROFILES` | Its service (host ports) |
|---|---|---|---|
| Neo4j | `graph-neo4j,sql-audit,opensearch1-search-client` | `nuxeo-graph-neo4j` | `nuxeo-neo4j`: Browser http://localhost:7476, Bolt 7691 (`neo4j` / `NUXEO_NEO4J_PASSWORD`, default `password`) |
| ArcadeDB | `graph-arcadedb,sql-audit,opensearch1-search-client` | `nuxeo-graph-arcadedb` | `nuxeo-arcadedb`: Studio http://localhost:2491 (`root` / `NUXEO_ARCADEDB_PASSWORD`, default `playwithdata`); database `nuxeo`, created on start |

## OpenArch

1. Build the image, OpenArch with the graph storage on its classpath:

   ```bash
   scripts/build-openarch-graph-storage.sh            # Windows: scripts\build-openarch-graph-storage.bat
   ```

   It builds openarch-graph-storage from GitHub at `OPENARCH_GRAPH_STORAGE_GIT_REF`, and OpenArch inside it at
   `OPENARCH_GIT_REF` (both in `.env`), all inside Docker: no JDK or Maven needed on the host. Pass a local
   openarch-graph-storage checkout folder to build that instead (tagged `:local`). The build takes several minutes the
   first time.

2. In `.env`:

   | Graph database | `OPENARCH_GRAPH_BACKEND` | Add to `COMPOSE_PROFILES` | Its service (host ports) |
   |---|---|---|---|
   | Neo4j | `neo4j` | `openarch-graph-neo4j` | `openarch-neo4j`: Browser http://localhost:7477, Bolt 7692 (`neo4j` / `OPENARCH_NEO4J_PASSWORD`, default `password`) |
   | ArcadeDB | `arcadedb` | `openarch-graph-arcadedb` | `openarch-arcadedb`: Studio http://localhost:2492 (`root` / `OPENARCH_ARCADEDB_PASSWORD`, default `playwithdata`); databases `openarch`, `openarch_vocabularies`, `openarch_configuration`, created by OpenArch |

   and `OPENARCH_IMAGE` set to the image the script printed, e.g.
   `OPENARCH_IMAGE=kg-spaces/openarch-graph-storage:d3df81f7b3026a067bd6711187667b987ec7cea4`.

## Example

Nuxeo on Neo4j and OpenArch on ArcadeDB, in `.env`:

```
COMPOSE_PROFILES=nuxeo-graph-neo4j,openarch-graph-arcadedb
NUXEO_TEMPLATES=graph-neo4j,sql-audit,opensearch1-search-client
OPENARCH_IMAGE=kg-spaces/openarch-graph-storage:d3df81f7b3026a067bd6711187667b987ec7cea4
OPENARCH_GRAPH_BACKEND=arcadedb
```

then `docker compose -p kg-spaces up -d`. Compose reads `COMPOSE_PROFILES` from `.env`, so the graph databases start
with the rest; add other profiles (`langflow`, `debug`) to the same comma-separated list.

## Checking it

- Nuxeo's log names the template: `docker compose -p kg-spaces logs nuxeo | grep "Include template"` shows
  `graph-neo4j` or `graph-arcadedb`.
- OpenArch's log names the database of each repository:
  `docker compose -p kg-spaces logs openarch | grep "connecting to"` shows `ArcadeDB at: openarch-arcadedb:2480/...` or
  `Neo4j at: bolt://openarch-neo4j:7687`.
- The documents are nodes there: in Neo4j Browser `MATCH (n) RETURN count(n)`; in ArcadeDB Studio, database `nuxeo`
  (Nuxeo) or `openarch` (OpenArch), `SELECT count(*) FROM NxDocument` for Nuxeo.

All four combinations (each repository on Neo4j or on ArcadeDB) were run this way on 2026-10-18: Nuxeo documents
created through its REST API land in its graph database, and OpenArch passes Flexible GraphRAG's OpenArch state-store
and scope tests.

## Trying it next to an existing deployment

A graph-backed repository starts empty, so to try graph storage without touching a deployment you already use, run it
as a second Compose project: a project name of its own gives it fresh volumes, and the first deployment's volumes
(its documents) stay as they are. Two projects can't use the same host ports at once, so either:

- **Stop the first one** (stopped containers hold no ports, and keep their data):

  ```bash
  docker compose -p kg-spaces stop
  docker compose -p kg-spaces-graph up -d nuxeo openarch   # with the graph settings in .env
  # ... and back:
  docker compose -p kg-spaces-graph down                    # add -v to delete its volumes too
  docker compose -p kg-spaces start
  ```

  `up -d nuxeo openarch` starts just those two, their databases and their graph databases, which is what graph storage
  changes. A complete second stack would not start next to the stopped one: Flexible GraphRAG's database compose files
  give their containers fixed names (`flexible-graphrag-neo4j`, ...), and a stopped container keeps its name. `.env` is
  shared by both projects (same folder): put the graph settings in for the second one, and take them out again before
  the first one is next recreated (`start` alone reuses its containers as they were).

- **Or move the second one's host ports**, so both run at once. In a copy of `.env`, change the host ports of the
  services you start (`OPENARCH_PORT`, `OPENARCH_MONGODB_PORT`, `OPENARCH_SEARCH_PORT`, `NUXEO_PORT`,
  `NUXEO_SEARCH_PORT`, `NUXEO_KAFKA_PORT`, ...) and start it with that file:

  ```bash
  docker compose -p kg-spaces-graph --env-file .env.graph up -d nuxeo openarch
  ```

  This is how the four combinations above were run, next to a running deployment (OpenArch on 8188, Nuxeo on 8181,
  ...). `--env-file` replaces `.env` for that command, so the copy needs every setting, not just the changed ones.

## Switching later

To move a component that already has data to a graph database (or back), start it on fresh volumes. Its existing
documents stay in the old volumes and are not moved. For OpenArch:

```bash
docker compose -p kg-spaces stop openarch
docker compose -p kg-spaces rm -f openarch openarch-mongodb openarch-search
docker volume rm kg-spaces_openarch-data kg-spaces_openarch-mongodb-data kg-spaces_openarch-search-data
docker compose -p kg-spaces up -d
```

and for Nuxeo the same with `nuxeo`, `nuxeo-db`, `nuxeo-search` and their volumes (`kg-spaces_nuxeo-data`,
`kg-spaces_nuxeo-db-data`, `kg-spaces_nuxeo-search-data`). This deletes that component's documents: data synced into
Flexible GraphRAG from it stays in Flexible GraphRAG's stores until removed there.
