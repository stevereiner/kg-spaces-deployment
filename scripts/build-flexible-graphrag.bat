@echo off
rem Build Flexible GraphRAG images from a checkout, for code not released yet (Windows; see build-flexible-graphrag.sh):
rem
rem   scripts\build-flexible-graphrag.bat <checkout> [--ui] [--langflow] [--no-backend]
rem
rem e.g. scripts\build-flexible-graphrag.bat C:\newdev3\flexible-graphrag --ui --langflow
rem --no-backend: only the --ui / --langflow images (the backend image is not rebuilt)
rem Then in .env: FLEXIBLE_GRAPHRAG_BACKEND_IMAGE=kg-spaces/flexible-graphrag-backend:local (and the UI and
rem FLEXIBLE_GRAPHRAG_LANGFLOW_IMAGE images)
setlocal
if "%~1"=="" (
  echo usage: scripts\build-flexible-graphrag.bat ^<checkout^> [--ui] [--langflow] [--no-backend]
  echo   e.g. scripts\build-flexible-graphrag.bat C:\newdev3\flexible-graphrag --ui --langflow
  exit /b 2
)
set "SRC=%~1"
shift
set "UI="
set "LANGFLOW="
set "NOBACKEND="
:args
if "%~1"=="" goto build
if "%~1"=="--ui" (set "UI=1" & shift & goto args)
if "%~1"=="--langflow" (set "LANGFLOW=1" & shift & goto args)
if "%~1"=="--no-backend" (set "NOBACKEND=1" & shift & goto args)
echo unknown option: %~1
exit /b 2

:build
if "%FLEXIBLE_GRAPHRAG_LOCAL_TAG%"=="" (set "TAG=local") else (set "TAG=%FLEXIBLE_GRAPHRAG_LOCAL_TAG%")

if not "%NOBACKEND%"=="" goto images
docker build -t kg-spaces/flexible-graphrag-backend:%TAG% "%SRC%\flexible-graphrag" || exit /b 1
:images
if not "%UI%"=="" (
  for %%N in (angular react vue) do (
    docker build -t kg-spaces/flexible-graphrag-ui-%%N:%TAG% "%SRC%\flexible-graphrag-ui\frontend-%%N" || exit /b 1
  )
)
if not "%LANGFLOW%"=="" (
  docker build -f "%SRC%\flexible-graphrag\Dockerfile.langflow" -t kg-spaces/flexible-graphrag-langflow:%TAG% "%SRC%\flexible-graphrag" || exit /b 1
)
echo Built kg-spaces/flexible-graphrag-*:%TAG% from %SRC%
