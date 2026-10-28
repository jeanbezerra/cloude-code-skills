@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Installs a bundled skill into a Claude Code skills directory.
set "SKILL_NAME=%~1"
if not defined SKILL_NAME set "SKILL_NAME=fluent-ui-react"
if not "%~3"=="" goto :usage
if not "%SKILL_NAME%"=="fluent-ui-react" if not "%SKILL_NAME%"=="fluent2-angular-21" if not "%SKILL_NAME%"=="all" goto :usage
set "SKILLS_DIR=%~2"
if not defined SKILLS_DIR set "SKILLS_DIR=%USERPROFILE%\.claude\skills"
if "%SKILL_NAME%"=="all" (
    call :install_one fluent-ui-react
    if errorlevel 1 exit /b 1
    call :install_one fluent2-angular-21
    if errorlevel 1 exit /b 1
    exit /b 0
)
call :install_one %SKILL_NAME%
exit /b %ERRORLEVEL%

:install_one
set "SOURCE_DIR=%~dp0%~1"
set "TARGET_DIR=%SKILLS_DIR%\%~1"
if not exist "%SOURCE_DIR%\SKILL.md" (
    echo ERRO: SKILL.md ausente em "%SOURCE_DIR%". >&2
    exit /b 1
)
if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if errorlevel 1 exit /b 1
xcopy "%SOURCE_DIR%\*" "%TARGET_DIR%\" /E /I /Y /Q >nul
if errorlevel 1 (
    echo ERRO: falha ao copiar a skill para "%TARGET_DIR%". >&2
    exit /b 1
)
if not exist "%TARGET_DIR%\SKILL.md" exit /b 1
echo Skill instalada: "%TARGET_DIR%"
echo No Claude Code, use: /%~1 sua tarefa
exit /b 0

:usage
echo Uso: install.cmd [fluent-ui-react^|fluent2-angular-21^|all] [pasta-de-skills-destino] >&2
echo Padrao: install.cmd fluent-ui-react "%USERPROFILE%\.claude\skills" >&2
exit /b 2
