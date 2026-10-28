@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "EXPECTED=%~2"
if not exist "%~1" exit /b 1
call :validate_expected
if errorlevel 1 exit /b 1
where certutil.exe >nul 2>&1
if errorlevel 1 (
    echo ERRO: certutil.exe necessario para validar SHA-256. Use Git Bash se estiver bloqueado. >&2
    exit /b 1
)
for /f "skip=1 delims=" %%H in ('certutil.exe -hashfile "%~1" SHA256 2^>nul') do (
    set "ACTUAL=%%H"
    call :compare_hash
    if not errorlevel 1 exit /b 0
)
echo ERRO: SHA-256 nao confere: "%~1" >&2
exit /b 1

:validate_expected
setlocal EnableDelayedExpansion
if "!EXPECTED:~63,1!"=="" goto :invalid_expected
if not "!EXPECTED:~64,1!"=="" goto :invalid_expected
echo(!EXPECTED!| findstr /r /x "[0-9a-fA-F]*" >nul
endlocal & exit /b %ERRORLEVEL%

:invalid_expected
endlocal & exit /b 1

:compare_hash
setlocal EnableDelayedExpansion
set "ACTUAL=!ACTUAL: =!"
if /i "!ACTUAL!"=="!EXPECTED!" (endlocal & exit /b 0)
endlocal & exit /b 1
