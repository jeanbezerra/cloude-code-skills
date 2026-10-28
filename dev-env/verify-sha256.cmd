@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "EXPECTED=%~2"
if not exist "%~1" exit /b 1
if "!EXPECTED:~63,1!"=="" exit /b 1
if not "!EXPECTED:~64,1!"=="" exit /b 1
echo(!EXPECTED!| findstr /r /x "[0-9a-fA-F]*" >nul
if errorlevel 1 exit /b 1
where certutil.exe >nul 2>&1
if errorlevel 1 (
    echo ERRO: certutil.exe necessario para validar SHA-256. Use Git Bash se estiver bloqueado. >&2
    exit /b 1
)
for /f "delims=" %%H in ('certutil.exe -hashfile "%~1" SHA256 2^>nul') do (
    set "ACTUAL=%%H"
    set "ACTUAL=!ACTUAL: =!"
    if /i "!ACTUAL!"=="!EXPECTED!" exit /b 0
)
echo ERRO: SHA-256 nao confere: %~1 >&2
exit /b 1
