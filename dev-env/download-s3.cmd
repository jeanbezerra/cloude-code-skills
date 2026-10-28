@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0env.cmd"
set "PLATFORM=%~1"
set "PRODUCT=%~2"
if not defined PLATFORM set "PLATFORM=windows-x64"
if not defined PRODUCT set "PRODUCT=all"
if not "!PLATFORM!"=="windows-x64" if not "!PLATFORM!"=="linux-x64" goto :usage
if not "!PRODUCT!"=="all" if not "!PRODUCT!"=="claude-code" if not "!PRODUCT!"=="claude-desktop" goto :usage
if not defined S3_BASE_URL (
    echo ERRO: configure S3_BASE_URL ou S3_BUCKET em env.local.cmd ou no CMD. >&2
    exit /b 1
)
if /i not "!S3_BASE_URL:~0,8!"=="https://" (
    echo ERRO: S3_BASE_URL deve comecar com https://. >&2
    exit /b 1
)
where curl.exe >nul 2>&1
if errorlevel 1 (
    echo ERRO: curl.exe nao encontrado no PATH. >&2
    exit /b 1
)
if not exist "!DEV_ENV_DOWNLOAD_DIR!" mkdir "!DEV_ENV_DOWNLOAD_DIR!"
if errorlevel 1 exit /b 1
set "CATALOG=!DEV_ENV_DOWNLOAD_DIR!\catalog-!RANDOM!-!RANDOM!.tmp"
if not defined DEV_ENV_CATALOG set "DEV_ENV_CATALOG=%~dp0artifacts\catalog.txt"
if not exist "!DEV_ENV_CATALOG!" (
    echo ERRO: catalogo local ausente: !DEV_ENV_CATALOG!. Obtenha-o junto dos scripts no Git. >&2
    exit /b 1
)
copy /b /y "!DEV_ENV_CATALOG!" "!CATALOG!" >nul
if errorlevel 1 goto :failed
set "COUNT=0"
set "FAILED="
for /f "usebackq tokens=1-4 delims=|" %%A in ("!CATALOG!") do (
    set "ROW_PRODUCT=%%A"
    set "ROW_PLATFORM=%%B"
    set "REL=%%C"
    set "SHA=%%D"
    if "!ROW_PLATFORM!"=="!PLATFORM!" (
        if "!PRODUCT!"=="all" (call :one) else if "!ROW_PRODUCT!"=="!PRODUCT!" call :one
        if errorlevel 1 set "FAILED=1"
    )
)
if defined FAILED goto :failed
if !COUNT! equ 0 (
    echo ERRO: nenhum artefato encontrado para !PLATFORM! / !PRODUCT!. >&2
    goto :failed
)
if not exist "!DEV_ENV_DOWNLOAD_DIR!\artifacts" mkdir "!DEV_ENV_DOWNLOAD_DIR!\artifacts"
move /y "!CATALOG!" "!DEV_ENV_DOWNLOAD_DIR!\artifacts\catalog.txt" >nul
if errorlevel 1 goto :failed
echo Download concluido: !COUNT! arquivo(s), SHA-256 validado.
exit /b 0

:one
if defined FAILED exit /b 1
if not "!ROW_PRODUCT!"=="claude-code" if not "!ROW_PRODUCT!"=="claude-desktop" exit /b 1
echo(!REL!| findstr /r /x "artifacts/[a-zA-Z0-9_./-]*" >nul
if errorlevel 1 exit /b 1
if not "!REL:..=!"=="!REL!" exit /b 1
if "!SHA:~63,1!"=="" exit /b 1
if not "!SHA:~64,1!"=="" exit /b 1
echo(!SHA!| findstr /r /x "[0-9a-fA-F]*" >nul
if errorlevel 1 exit /b 1
set "TARGET=!DEV_ENV_DOWNLOAD_DIR!\!REL:/=\!"
for %%D in ("!TARGET!") do if not exist "%%~dpD" mkdir "%%~dpD"
if errorlevel 1 exit /b 1
echo Baixando !ROW_PRODUCT! / !PLATFORM!...
curl.exe --fail --location --silent --show-error --retry 3 --connect-timeout 20 --proto "=https" --proto-redir "=https" "!S3_BASE_URL!/!REL!" -o "!TARGET!.part"
if errorlevel 1 goto :row_failed
call "%~dp0verify-sha256.cmd" "!TARGET!.part" "!SHA!"
if errorlevel 1 goto :row_failed
move /y "!TARGET!.part" "!TARGET!" >nul
if errorlevel 1 goto :row_failed
set /a COUNT+=1 >nul
exit /b 0

:row_failed
if exist "!TARGET!.part" del /q "!TARGET!.part"
exit /b 1

:failed
if defined CATALOG if exist "!CATALOG!" del /q "!CATALOG!"
echo ERRO: download interrompido; confira URL, acesso publico, proxy e hashes. >&2
exit /b 1

:usage
echo Uso: download-s3.cmd [windows-x64^|linux-x64] [all^|claude-code^|claude-desktop] >&2
exit /b 2
