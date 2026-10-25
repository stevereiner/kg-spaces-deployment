@echo off
rem Build OpenArch with its repositories on a graph database (Windows; see build-openarch-graph-storage.sh):
rem
rem   scripts\build-openarch-graph-storage.bat [<checkout folder>]
rem
rem Then in .env: OPENARCH_IMAGE=kg-spaces/openarch-graph-storage:<ref>, OPENARCH_GRAPH_BACKEND=neo4j (or arcadedb),
rem COMPOSE_PROFILES=openarch-graph-neo4j (or openarch-graph-arcadedb)
setlocal
set "HERE=%~dp0.."
for /f "tokens=1,* delims==" %%A in ('findstr /b "OPENARCH_GIT_REF=" "%HERE%\.env"') do set "OPENARCH_REF=%%B"
if "%OPENARCH_REF%"=="" (
  echo OPENARCH_GIT_REF is not set in .env
  exit /b 2
)
if not "%~1"=="" if exist "%~1\docker\Dockerfile" (
  docker build --build-arg "OPENARCH_GIT_REF=%OPENARCH_REF%" -f "%~1\docker\Dockerfile" -t kg-spaces/openarch-graph-storage:local "%~1" || exit /b 1
  echo Built kg-spaces/openarch-graph-storage:local -- set OPENARCH_IMAGE=kg-spaces/openarch-graph-storage:local in .env
  exit /b 0
)
for /f "tokens=1,* delims==" %%A in ('findstr /b "OPENARCH_GRAPH_STORAGE_GIT_REF=" "%HERE%\.env"') do set "REF=%%B"
if "%REF%"=="" (
  echo OPENARCH_GRAPH_STORAGE_GIT_REF is not set in .env
  exit /b 2
)
docker build --build-arg "OPENARCH_GIT_REF=%OPENARCH_REF%" -f docker/Dockerfile -t kg-spaces/openarch-graph-storage:%REF% "https://github.com/stevereiner/openarch-graph-storage.git#%REF%" || exit /b 1
echo Built kg-spaces/openarch-graph-storage:%REF% -- set OPENARCH_IMAGE=kg-spaces/openarch-graph-storage:%REF% in .env
