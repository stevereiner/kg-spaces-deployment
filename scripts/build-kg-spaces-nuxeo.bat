@echo off
rem Build KG Spaces for Nuxeo (Windows; see build-kg-spaces-nuxeo.sh): the app image and its Web UI
rem add-on jar, into nuxeo\addons\. Then: docker compose -p kg-spaces up -d kg-spaces-nuxeo, and restart nuxeo.
rem
rem From GitHub at KG_SPACES_NUXEO_GIT_REF, or a local checkout at KG_SPACES_NUXEO_CONTEXT (both in .env).
setlocal
set "HERE=%~dp0.."
set "CONTEXT="
set "REF="
for /f "tokens=1,* delims==" %%A in ('findstr /b "KG_SPACES_NUXEO_CONTEXT=" "%HERE%\.env"') do set "CONTEXT=%%B"
for /f "tokens=1,* delims==" %%A in ('findstr /b "KG_SPACES_NUXEO_GIT_REF=" "%HERE%\.env"') do set "REF=%%B"
if "%REF%"=="" set "REF=main"
if "%CONTEXT%"=="" (
  set "CONTEXT=https://github.com/stevereiner/kg-spaces-nuxeo.git#%REF%"
  set "DOCKERFILE=docker/Dockerfile"
  goto :build
)
rem A Git URL: the Dockerfile relative to the repository
if not "%CONTEXT:://=%"=="%CONTEXT%" (
  set "DOCKERFILE=docker/Dockerfile"
  goto :build
)
rem A local checkout: relative to the deployment, unless absolute (C:\... or \\server\...)
if not "%CONTEXT:~1,1%"==":" if not "%CONTEXT:~0,2%"=="\\" set "CONTEXT=%HERE%\%CONTEXT%"
set "DOCKERFILE=%CONTEXT%\docker\Dockerfile"
:build
if not exist "%HERE%\nuxeo\addons" mkdir "%HERE%\nuxeo\addons"
del /q "%HERE%\nuxeo\addons\kg-spaces-nuxeo-addon-*.jar" 2>nul
docker build -f "%DOCKERFILE%" --target addon --output "%HERE%\nuxeo\addons" "%CONTEXT%" || exit /b 1
pushd "%HERE%" && docker compose -p kg-spaces build kg-spaces-nuxeo & popd
echo Built the app image and the add-on in nuxeo\addons -- restart Nuxeo to install the add-on
