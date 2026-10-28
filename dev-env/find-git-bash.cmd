@echo off
setlocal EnableExtensions
set "_DEV_GIT_CALLER_DELAYED="
if "!"=="" set "_DEV_GIT_CALLER_DELAYED=1"
setlocal DisableDelayedExpansion
rem Returns the validated Git Bash path in CLAUDE_CODE_GIT_BASH_PATH.
rem An explicit override is authoritative, including when it is invalid.
set "_DEV_GIT_QUIET="
set "_DEV_GIT_FOUND="
set "_DEV_GIT_CANDIDATE="
set "_DEV_GIT_ROOT="
if "%~1"=="--quiet" set "_DEV_GIT_QUIET=1"
if defined CLAUDE_CODE_GIT_BASH_PATH goto :explicit

for %%D in ("%ProgramFiles%\Git" "%ProgramFiles(x86)%\Git" "%LOCALAPPDATA%\Programs\Git") do (
    set "_DEV_GIT_ROOT=%%~D"
    call :try_root
)
if defined _DEV_GIT_FOUND goto :success

rem Both registry views cover machine-wide, per-user and custom installations.
for %%H in (HKCU HKLM) do for %%V in (64 32) do (
    for /f "tokens=2,*" %%A in ('reg.exe query "%%H\Software\GitForWindows" /v InstallPath /reg:%%V 2^>nul') do (
        if "%%A"=="REG_SZ" (
            set "_DEV_GIT_ROOT=%%B"
            call :try_root
        )
    )
)
if defined _DEV_GIT_FOUND goto :success

rem Git can expose cmd\git.exe, bin\git.exe or mingw64\bin\git.exe.
for /f "delims=" %%G in ('where.exe git.exe 2^>nul') do (
    for %%R in ("%%~dpG." "%%~dpG.." "%%~dpG..\..") do (
        set "_DEV_GIT_ROOT=%%~fR"
        call :try_root
    )
)
if defined _DEV_GIT_FOUND goto :success

for /f "delims=" %%B in ('where.exe bash.exe 2^>nul') do (
    set "_DEV_GIT_CANDIDATE=%%B"
    call :try_candidate
)
if defined _DEV_GIT_FOUND goto :success
if not defined _DEV_GIT_QUIET (
    echo Nao encontrei uma instalacao funcional do Git Bash. >&2
    echo Instale o Git for Windows pelo canal da empresa e execute novamente. >&2
    echo Se ele estiver em outra pasta, ajuste CLAUDE_CODE_GIT_BASH_PATH em env.local.cmd. >&2
)
endlocal & endlocal & exit /b 1

:explicit
set "_DEV_GIT_CANDIDATE=%CLAUDE_CODE_GIT_BASH_PATH%"
call :try_candidate
if defined _DEV_GIT_FOUND goto :success
if not defined _DEV_GIT_QUIET (
    echo O caminho configurado em CLAUDE_CODE_GIT_BASH_PATH nao e um Git Bash funcional. >&2
    echo Caminho: "%CLAUDE_CODE_GIT_BASH_PATH%" >&2
    echo Corrija o caminho ou remova a variavel para permitir a deteccao automatica. >&2
)
endlocal & endlocal & exit /b 1

:try_root
if defined _DEV_GIT_FOUND exit /b 0
set "_DEV_GIT_CANDIDATE=%_DEV_GIT_ROOT%\bin\bash.exe"
call :try_candidate
if defined _DEV_GIT_FOUND exit /b 0
set "_DEV_GIT_CANDIDATE=%_DEV_GIT_ROOT%\usr\bin\bash.exe"
call :try_candidate
exit /b 0

:try_candidate
if defined _DEV_GIT_FOUND exit /b 0
if not exist "%_DEV_GIT_CANDIDATE%" exit /b 1
rem Never launch the WSL shim while searching the PATH.
for %%B in ("%_DEV_GIT_CANDIDATE%") do set "_DEV_GIT_CANDIDATE=%%~fB"
if /i "%_DEV_GIT_CANDIDATE%"=="%SystemRoot%\System32\bash.exe" exit /b 1
if /i "%_DEV_GIT_CANDIDATE%"=="%SystemRoot%\Sysnative\bash.exe" exit /b 1
rem uname distinguishes Git for Windows from Linux/WSL and Cygwin Bash.
"%_DEV_GIT_CANDIDATE%" --noprofile --norc -c "case $(/usr/bin/uname -s) in MINGW*|MSYS*) exit 0;; *) exit 1;; esac" >nul 2>&1
if errorlevel 1 exit /b 1
set "_DEV_GIT_FOUND=%_DEV_GIT_CANDIDATE%"
exit /b 0

:success
if not defined _DEV_GIT_QUIET echo Git Bash encontrado: "%_DEV_GIT_FOUND%"
if defined _DEV_GIT_CALLER_DELAYED goto :export_delayed
endlocal & endlocal & set "CLAUDE_CODE_GIT_BASH_PATH=%_DEV_GIT_FOUND%" & exit /b 0

:export_delayed
rem Protect literal carets and bangs when the caller enabled delayed expansion.
set "_DEV_GIT_EXPORT=%_DEV_GIT_FOUND:^=^^%"
set "_DEV_GIT_EXPORT=%_DEV_GIT_EXPORT:!=^!%"
endlocal & endlocal & set "CLAUDE_CODE_GIT_BASH_PATH=%_DEV_GIT_EXPORT%" & exit /b 0
