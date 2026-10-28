@echo off
rem Run with CALL from an existing CMD so the environment stays available.
call "%~dp0dev-env\setup.cmd" %*
exit /b %ERRORLEVEL%
