@echo off
rem First run (and later runs) of the KG Spaces deployment on Windows (see setup.sh): checks Docker, runs the step
rem scripts in scripts\ that are still needed, and starts the stack. Steps already done are skipped.
rem
rem   setup.bat [full|alfresco|nuxeo|none] [--sync] [--rebuild]          from PowerShell: .\setup.bat
rem
rem   full | alfresco | nuxeo | none   the content repositories run in this deployment (default: as COMPOSE_PROFILES
rem               in .env has them, full in a fresh clone); OpenArch and Flexible GraphRAG always run. A repository
rem               outside this deployment: ALFRESCO_SERVER_URL / NUXEO_SERVER_URL in .env (its KG Spaces app runs here)
rem   --sync      copy Flexible GraphRAG's files again (scripts/sync-flexible-graphrag.sh), even when present, and
rem               its settings sample (flexible-graphrag.env.sample)
rem   --rebuild   build the OpenArch and KG Spaces for Nuxeo images again, and start with --build
rem
rem The sync step is a POSIX shell script: it runs with Git for Windows' bash. Optional services (langflow, debug,
rem graph storage): COMPOSE_PROFILES in .env.
setlocal
cd /d "%~dp0"
set "REPOSITORIES="
set "SYNC="
set "REBUILD="
:args
if "%~1"=="" goto docker
if "%~1"=="full" (set "REPOSITORIES=full" & shift & goto args)
if "%~1"=="alfresco" (set "REPOSITORIES=alfresco" & shift & goto args)
if "%~1"=="nuxeo" (set "REPOSITORIES=nuxeo" & shift & goto args)
if "%~1"=="none" (set "REPOSITORIES=none" & shift & goto args)
if "%~1"=="--sync" (set "SYNC=1" & shift & goto args)
if "%~1"=="--rebuild" (set "REBUILD=1" & shift & goto args)
echo unknown option: %~1 (use full, alfresco, nuxeo, none, --sync, --rebuild)
exit /b 2

:docker
echo.
echo 1/7  Docker
docker info >nul 2>&1
if errorlevel 1 (
  echo Docker is not running: start Docker Desktop and run setup again.
  exit /b 1
)
docker compose version

echo.
echo 2/7  Content repositories
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\set-repositories.ps1 %REPOSITORIES% || exit /b 1
call :setting COMPOSE_PROFILES PROFILES .env
rem ",<profiles>," to test for ",<name>," in it
set "P=,%PROFILES%,"

echo.
echo 3/7  Flexible GraphRAG's database compose files, schemas and flows
call :setting FLEXIBLE_GRAPHRAG_VERSION VERSION .env
rem a fresh clone gets the files git doesn't keep, and keeps the committed settings sample; --sync replaces it too
set "SYNCARGS="
if defined SYNC goto sync
set "SYNCARGS=--keep-sample"
if not exist "flexible-graphrag\docker\includes" goto sync
if not exist "flexible-graphrag\schemas" goto sync
echo present (flexible-graphrag\docker\includes); --sync copies them again
goto fgenv
:sync
set "BASH="
if exist "%ProgramFiles%\Git\bin\bash.exe" set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not defined BASH for /f "delims=" %%G in ('where git 2^>nul') do if not defined BASH if exist "%%~dpG..\bin\bash.exe" set "BASH=%%~dpG..\bin\bash.exe"
if not defined BASH (
  echo Git for Windows' bash not found: install Git for Windows, or run in Git Bash: sh scripts/sync-flexible-graphrag.sh v%VERSION%
  exit /b 1
)
"%BASH%" scripts/sync-flexible-graphrag.sh v%VERSION% %SYNCARGS% || exit /b 1

:fgenv
echo.
echo 4/7  flexible-graphrag.env
call :setting INCREMENTAL_STATE_STORE STATE .env
if not defined STATE set "STATE=postgres"
if exist flexible-graphrag.env goto checkenv
copy flexible-graphrag.env.sample flexible-graphrag.env >nul
echo Made flexible-graphrag.env from flexible-graphrag.env.sample. Set up in it, then run setup again:
echo - your LLM and embedding providers (LLM_PROVIDER, EMBEDDING_KIND), and their key if they need one: the sample
echo   uses OpenAI (OPENAI_API_KEY); Ollama needs no key
echo - optionally Hyland OpenArch as the search + vector store: ENABLE_OPENARCH=true. OpenArch indexes 1024-dimension
echo   vectors only: an embedding model that gives 1024 (e.g. Ollama's mxbai-embed-large) or can be set to 1024
echo   (OpenAI's text-embedding-3-small / -large: OPENAI_EMBEDDING_DIMENSION=1024). Without it, Flexible GraphRAG's
echo   VECTOR_DB and SEARCH_DB are used
if not "%STATE%"=="openarch" goto statepostgres
echo Data sources and document state are kept in OpenArch trees (INCREMENTAL_STATE_STORE=openarch in .env;
echo INCREMENTAL_STATE_STORE=postgres there keeps them in PostgreSQL).
exit /b 1
:statepostgres
echo Data sources and document state are kept in PostgreSQL (INCREMENTAL_STATE_STORE=openarch in .env keeps them
echo in OpenArch trees).
exit /b 1
:checkenv
call :setting LLM_PROVIDER LLM flexible-graphrag.env
call :setting EMBEDDING_KIND EMBEDDING flexible-graphrag.env
call :setting OPENAI_API_KEY KEY flexible-graphrag.env
call :setting ENABLE_OPENARCH OPENARCH flexible-graphrag.env
call :setting OPENAI_EMBEDDING_DIMENSION DIMENSION flexible-graphrag.env
call :setting RDF_GRAPH_DB RDF flexible-graphrag.env
if not defined OPENARCH set "OPENARCH=false"
set "USES_OPENAI="
if "%LLM%"=="openai" set "USES_OPENAI=1"
if "%EMBEDDING%"=="openai" set "USES_OPENAI=1"
if not defined USES_OPENAI goto openarchdim
if not defined KEY goto nokey
if "%KEY%"=="your-openai-api-key-here" goto nokey
goto openarchdim
:nokey
echo flexible-graphrag.env uses OpenAI (LLM_PROVIDER / EMBEDDING_KIND) but OPENAI_API_KEY is not set: set it, or
echo switch to a provider that needs no key (e.g. ollama), then run setup again.
exit /b 1
:openarchdim
set "KEY="
if not "%OPENARCH%"=="true" goto graphdb
if not "%EMBEDDING%"=="openai" goto otherdim
if "%DIMENSION%"=="1024" goto graphdb
if not defined DIMENSION set "DIMENSION=not set"
echo ENABLE_OPENARCH=true: OpenArch indexes 1024-dimension vectors only; set OPENAI_EMBEDDING_DIMENSION=1024
echo (now %DIMENSION%) in flexible-graphrag.env, then run setup again.
exit /b 1
:otherdim
echo Note: ENABLE_OPENARCH=true: OpenArch indexes 1024-dimension vectors only; EMBEDDING_KIND=%EMBEDDING% must give 1024.
:graphdb
if not "%RDF%"=="graphdb" goto envok
if exist "flexible-graphrag\docker\ontotext-graphdb\GRAPHDB.license" goto envok
echo Note: RDF_GRAPH_DB=graphdb without flexible-graphrag\docker\ontotext-graphdb\GRAPHDB.license: GraphDB fails
echo every write and query (README: RDF graph database).
:envok
echo ok (LLM_PROVIDER=%LLM%, EMBEDDING_KIND=%EMBEDDING%, ENABLE_OPENARCH=%OPENARCH%; .env: INCREMENTAL_STATE_STORE=%STATE%)

echo.
echo 5/7  OpenArch image
call :setting OPENARCH_IMAGE IMAGE .env
call :setting OPENARCH_GIT_REF REF .env
if defined IMAGE goto openarchimage
call :setting OPENARCH_VERSION OAVERSION .env
echo Hyland's published image, OPENARCH_VERSION=%OAVERSION% (pulled at start)
goto nuxeoaddon
:openarchimage
if defined REBUILD goto buildopenarch
docker image inspect "%IMAGE%" >nul 2>&1
if errorlevel 1 goto buildopenarch
echo present: %IMAGE%
goto nuxeoaddon
:buildopenarch
if not "%IMAGE%"=="kg-spaces/openarch-all-mongodb:%REF%" goto otheropenarch
call scripts\build-openarch.bat %REF% || exit /b 1
goto nuxeoaddon
:otheropenarch
echo OPENARCH_IMAGE=%IMAGE% is not built: build it with scripts\build-openarch-graph-storage.bat
echo (docs/graph-storage.md), or comment it out in .env for Hyland's published image.
exit /b 1

:nuxeoaddon
echo.
echo 6/7  KG Spaces for Nuxeo: Web UI add-on and app image
if not "%P:,kg-spaces-nuxeo,=%"=="%P%" goto nuxeoused
echo not used (no Nuxeo here or NUXEO_SERVER_URL)
goto start
:nuxeoused
if defined REBUILD goto buildnuxeo
if not exist "nuxeo\addons\kg-spaces-nuxeo-addon-*.jar" goto buildnuxeo
for %%J in ("nuxeo\addons\kg-spaces-nuxeo-addon-*.jar") do echo present: nuxeo\addons\%%~nxJ
goto externalnuxeo
:buildnuxeo
call scripts\build-kg-spaces-nuxeo.bat || exit /b 1
:externalnuxeo
if not "%P:,nuxeo,=%"=="%P%" goto start
call :setting KG_SPACES_NUXEO_URL KGNUXEOURL .env
echo Nuxeo outside this deployment: install the add-on there for Web UI's KG Spaces menu (copy
echo nuxeo\addons\kg-spaces-nuxeo-addon-*.jar into its nxserver/bundles/, add
echo kgspaces.url=%KGNUXEOURL% to its nuxeo.conf, restart it), and open its Web UI through
echo this deployment's proxy (/nuxeo/ui/), so the app shares the sign-in (README: Repositories outside this deployment).

:start
echo.
echo 7/7  Starting the stack
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-ports.ps1 || exit /b 1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\remove-detached.ps1 || exit /b 1
set "BUILDS="
if not "%P:,nuxeo,=%"=="%P%" set "BUILDS=Nuxeo with its Web UI: an hour or more; "
if not "%P:,kg-spaces-aca,=%"=="%P%" set "BUILDS=%BUILDS%KG Spaces ACA: a few minutes"
if defined BUILDS echo The first start builds the images still missing (%BUILDS%). Later starts are quick.
if defined REBUILD (
  docker compose -p kg-spaces up -d --build || exit /b 1
) else (
  docker compose -p kg-spaces up -d || exit /b 1
)

call :setting PROXY_PORT PORT .env
call :setting KG_SPACES_HOST HOST .env
if not defined PORT set "PORT=8080"
if not defined HOST set "HOST=localhost"
echo.
echo Started. Landing page: http://%HOST%:%PORT% (links to every app).
echo Status: docker compose -p kg-spaces ps    Logs: docker compose -p kg-spaces logs -f ^<service^>
exit /b 0

rem :setting NAME VAR FILE -- VAR = the value of NAME= in FILE (its first uncommented line), up to the first space
rem (no trailing comment), empty if none
:setting
set "%~2="
for /f "tokens=1,* delims==" %%A in ('findstr /b /c:"%~1=" "%~3"') do if not defined %~2 for /f "tokens=1" %%V in ("%%B") do set "%~2=%%V"
exit /b 0
