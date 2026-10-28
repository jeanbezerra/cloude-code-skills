@echo off
setlocal EnableExtensions DisableDelayedExpansion
call "%~dp0env.cmd"
if not "%~1"=="" if not "%~1"=="windows-x64" (
    echo Uso: install-cli.cmd [windows-x64]. Para Linux, use install-cli.sh no Linux. >&2
    exit /b 2
)
call "%~dp0find-git-bash.cmd" --quiet
if errorlevel 1 goto :bash_missing
if not "%~2"=="" exit /b 2
set "CATALOG=%DEV_ENV_CATALOG%"
if not exist "%CATALOG%" (
    echo ERRO: catalogo ausente. Obtenha artifacts\catalog.txt junto com os scripts do kit. >&2
    exit /b 1
)
set "CLI_REL="
set "SHA="
for /f "usebackq tokens=1-4 delims=|" %%A in ("%CATALOG%") do (
    if "%%A"=="claude-code" if "%%B"=="windows-x64" (
        set "CLI_REL=%%C"
        set "SHA=%%D"
    )
)
if not defined CLI_REL (
    echo Nao encontrei a CLI Windows x64 no catalogo local. >&2
    exit /b 1
)
call :validate_entry
if errorlevel 1 exit /b 1
set "SOURCE=%DEV_ENV_DOWNLOAD_DIR%\%CLI_REL:/=\%"
if not exist "%SOURCE%" set "SOURCE=%~dp0%CLI_REL:/=\%"
if not exist "%SOURCE%" (
    echo A CLI ainda nao esta no pacote local nem no cache de downloads.
    exit /b 1
)
call "%~dp0verify-sha256.cmd" "%SOURCE%" "%SHA%"
if errorlevel 1 exit /b 1
if not exist "%DEV_ENV_INSTALL_DIR%" mkdir "%DEV_ENV_INSTALL_DIR%"
if errorlevel 1 exit /b 1
copy /b /y "%SOURCE%" "%DEV_ENV_INSTALL_DIR%\claude.exe.part" >nul
if errorlevel 1 exit /b 1
call "%~dp0verify-sha256.cmd" "%DEV_ENV_INSTALL_DIR%\claude.exe.part" "%SHA%"
if errorlevel 1 (
    del /q "%DEV_ENV_INSTALL_DIR%\claude.exe.part"
    exit /b 1
)
move /y "%DEV_ENV_INSTALL_DIR%\claude.exe.part" "%DEV_ENV_INSTALL_DIR%\claude.exe" >nul
if errorlevel 1 exit /b 1
echo CLI instalada em: "%DEV_ENV_INSTALL_DIR%\claude.exe"
echo Nesta janela execute: call "%~dp0env.cmd"
echo Depois verifique: claude --version
exit /b 0

:validate_entry
rem Delayed expansion is used only for catalog fields, never filesystem paths.
setlocal EnableDelayedExpansion
echo(!CLI_REL!| findstr /r /x "artifacts/[a-zA-Z0-9_./-]*" >nul
if errorlevel 1 goto :invalid_entry
if not "!CLI_REL:..=!"=="!CLI_REL!" goto :invalid_entry
if "!SHA:~63,1!"=="" goto :invalid_entry
if not "!SHA:~64,1!"=="" goto :invalid_entry
echo(!SHA!| findstr /r /x "[0-9a-fA-F]*" >nul
endlocal & exit /b %ERRORLEVEL%

:invalid_entry
endlocal & exit /b 1

:bash_missing
echo Nao encontrei um Git Bash funcional. Instale o Git for Windows pelo canal da empresa. >&2
echo Se ele ja estiver instalado, confira CLAUDE_CODE_GIT_BASH_PATH em env.local.cmd. >&2
exit /b 1
