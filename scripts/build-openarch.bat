@echo off
rem Build OpenArch from its GitHub repository at a commit (Windows; see build-openarch.sh):
rem
rem   scripts\build-openarch.bat [<commit or branch>]      default: OPENARCH_GIT_REF in .env
rem
rem Then in .env: OPENARCH_IMAGE=kg-spaces/openarch-all-mongodb:<ref>
setlocal
set "HERE=%~dp0.."
set "REF=%~1"
if "%REF%"=="" for /f "tokens=1,* delims==" %%A in ('findstr /b "OPENARCH_GIT_REF=" "%HERE%\.env"') do set "REF=%%B"
if "%REF%"=="" (
  echo usage: scripts\build-openarch.bat ^<commit or branch^> ^(or set OPENARCH_GIT_REF in .env^)
  exit /b 2
)
docker build --build-arg "OPENARCH_GIT_REF=%REF%" -t kg-spaces/openarch-all-mongodb:%REF% "%HERE%\openarch" || exit /b 1
echo Built kg-spaces/openarch-all-mongodb:%REF% -- set OPENARCH_IMAGE=kg-spaces/openarch-all-mongodb:%REF% in .env
