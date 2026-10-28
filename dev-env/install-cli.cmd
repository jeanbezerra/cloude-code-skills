@echo off
setlocal EnableExtensions EnableDelayedExpansion
call "%~dp0env.cmd"
if not "%~1"=="" if not "%~1"=="windows-x64" (
    echo Uso: install-cli.cmd [windows-x64]. Para Linux, use install-cli.sh no Linux. >&2
    exit /b 2
)
if not defined CLAUDE_CODE_GIT_BASH_PATH goto :bash_missing
if not exist "!CLAUDE_CODE_GIT_BASH_PATH!" goto :bash_missing
set "CATALOG=!DEV_ENV_DOWNLOAD_DIR!\artifacts\catalog.txt"
set "SOURCE_ROOT=!DEV_ENV_DOWNLOAD_DIR!"
if not exist "!CATALOG!" (
    set "CATALOG=%~dp0artifacts\catalog.txt"
    set "SOURCE_ROOT=%~dp0"
)
if not exist "!CATALOG!" (
    echo ERRO: catalogo ausente; execute download-s3.cmd primeiro. >&2
    exit /b 1
)
set "CLI_REL="
for /f "usebackq tokens=1-4 delims=|" %%A in ("!CATALOG!") do (
    if "%%A"=="claude-code" if "%%B"=="windows-x64" (
        set "CLI_REL=%%C"
        set "SHA=%%D"
    )
)
if not defined CLI_REL exit /b 1
echo(!CLI_REL!| findstr /r /x "artifacts/[a-zA-Z0-9_./-]*" >nul
if errorlevel 1 exit /b 1
if not "!CLI_REL:..=!"=="!CLI_REL!" exit /b 1
set "SOURCE=!SOURCE_ROOT!\!CLI_REL:/=\!"
if not exist "!SOURCE!" if exist "%~dp0!CLI_REL:/=\!" set "SOURCE=%~dp0!CLI_REL:/=\!"
call "%~dp0verify-sha256.cmd" "!SOURCE!" "!SHA!"
if errorlevel 1 exit /b 1
if not exist "!DEV_ENV_INSTALL_DIR!" mkdir "!DEV_ENV_INSTALL_DIR!"
if errorlevel 1 exit /b 1
copy /b /y "!SOURCE!" "!DEV_ENV_INSTALL_DIR!\claude.exe.part" >nul
if errorlevel 1 exit /b 1
call "%~dp0verify-sha256.cmd" "!DEV_ENV_INSTALL_DIR!\claude.exe.part" "!SHA!"
if errorlevel 1 (
    del /q "!DEV_ENV_INSTALL_DIR!\claude.exe.part"
    exit /b 1
)
move /y "!DEV_ENV_INSTALL_DIR!\claude.exe.part" "!DEV_ENV_INSTALL_DIR!\claude.exe" >nul
if errorlevel 1 exit /b 1
echo CLI copiada para !DEV_ENV_INSTALL_DIR!\claude.exe
echo Nesta janela execute: call "%~dp0env.cmd"
echo Depois verifique: claude --version
exit /b 0

:bash_missing
echo ERRO: configure CLAUDE_CODE_GIT_BASH_PATH com o bash.exe do Git for Windows. >&2
echo O Git Bash e necessario neste ambiente sem PowerShell. >&2
exit /b 1
