@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem Optional maintainer command. AWS CLI is NOT needed on the target computer.
call "%~dp0env.cmd"
if not "%~1"=="" if not "%~1"=="--dryrun" (
    echo Uso: publish-s3.cmd [--dryrun] >&2
    exit /b 2
)
if not defined S3_BUCKET (
    echo ERRO: configure S3_BUCKET, S3_REGION e S3_PREFIX antes de publicar. >&2
    exit /b 1
)
if not defined AWS_CLI_EXE where aws.exe >nul 2>&1
if not defined AWS_CLI_EXE if not errorlevel 1 set "AWS_CLI_EXE=aws.exe"
if not defined AWS_CLI_EXE if exist "%LOCALAPPDATA%\Programs\Amazon\AWSCLIV2\aws.exe" set "AWS_CLI_EXE=%LOCALAPPDATA%\Programs\Amazon\AWSCLIV2\aws.exe"
if not defined AWS_CLI_EXE if exist "%ProgramFiles%\Amazon\AWSCLIV2\aws.exe" set "AWS_CLI_EXE=%ProgramFiles%\Amazon\AWSCLIV2\aws.exe"
if not defined AWS_CLI_EXE (
    echo ERRO: AWS CLI necessario somente na maquina que publica os arquivos. >&2
    exit /b 1
)
if not exist "%~dp0artifacts\catalog.txt" (
    echo ERRO: catalogo ausente; gere-o antes de publicar. >&2
    exit /b 1
)
for /f "usebackq tokens=1-4 delims=|" %%A in ("%~dp0artifacts\catalog.txt") do (
    set "ROW_PRODUCT=%%A"
    set "ROW_PLATFORM=%%B"
    set "REL=%%C"
    set "SHA=%%D"
    call :check_binary
    if errorlevel 1 exit /b 1
)
rem Upload ONLY the binaries listed in the local catalog. No directory sync.
rem Scripts, catalogs, metadata and credentials are never uploaded.
for /f "usebackq tokens=1-4 delims=|" %%A in ("%~dp0artifacts\catalog.txt") do (
    "%AWS_CLI_EXE%" s3 cp "%~dp0%%C" "s3://%S3_BUCKET%/%S3_PREFIX%/%%C" --region "%S3_REGION%" --sse AES256 --content-type "application/octet-stream" --cache-control "no-cache" --no-progress --no-cli-pager %~1
    if errorlevel 1 exit /b 1
)
exit /b 0

:check_binary
echo(!REL!| findstr /r /x "artifacts/[a-zA-Z0-9_./-]*" >nul
if errorlevel 1 goto :not_binary
if not "!REL:..=!"=="!REL!" goto :not_binary
if "!ROW_PRODUCT!"=="claude-code" if "!ROW_PLATFORM!"=="windows-x64" if "!REL:~-16!"=="-windows-x64.exe" goto :verify_binary
if "!ROW_PRODUCT!"=="claude-code" if "!ROW_PLATFORM!"=="linux-x64" if "!REL:~-10!"=="-linux-x64" goto :verify_binary
if "!ROW_PRODUCT!"=="claude-desktop" if "!ROW_PLATFORM!"=="windows-x64" if "!REL:~-17!"=="-windows-x64.msix" goto :verify_binary
if "!ROW_PRODUCT!"=="claude-desktop" if "!ROW_PLATFORM!"=="linux-x64" if "!REL:~-14!"=="-linux-x64.deb" goto :verify_binary
:not_binary
echo ERRO: o catalogo deve listar apenas binarios com nomes normalizados. >&2
exit /b 1
:verify_binary
call "%~dp0verify-sha256.cmd" "%~dp0!REL!" "!SHA!"
exit /b !ERRORLEVEL!
