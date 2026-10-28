@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "SETUP_SESSION_ONLY="
set "DEV_ENV_SKIP_CERTIFICATE="
if /i "%~1"=="--session-only" set "SETUP_SESSION_ONLY=1"
if not "%~1"=="" if not defined SETUP_SESSION_ONLY goto :usage
if not "%~2"=="" goto :usage
call "%~dp0env.cmd"
if not defined CLAUDE_CONFIG_DIR set "CLAUDE_CONFIG_DIR=%USERPROFILE%\.claude"
if not defined DEV_ENV_GENIAL_URL set "DEV_ENV_GENIAL_URL=https://genial-lite.plataforma-gen-ia.prd.awsporto"

echo.
echo ============================================================
echo  Vamos preparar o Claude Code para usar o Genial
echo ============================================================
echo  Sao 6 etapas. Vou explicar o que acontece em cada uma.
echo  Voce so precisa ter sua API Key do Genial em maos.
echo.
echo [1/6] Conferindo o que precisamos neste computador
call "%~dp0find-git-bash.cmd"
if errorlevel 1 goto :failed
where cscript.exe >nul 2>&1
if errorlevel 1 goto :runtime_missing
cscript.exe //nologo //E:JScript "%~dp0setup-config.js" check-runtime
if errorlevel 1 goto :runtime_missing
where certutil.exe >nul 2>&1
if errorlevel 1 (
    echo Nao encontrei o certutil.exe, necessario para conferir os arquivos.
    echo Solicite a disponibilidade dessa ferramenta a sua equipe de TI.
    goto :failed
)
echo Tudo certo. Vamos instalar a CLI antes de configurar sua conta.
echo.
echo [2/6] Instalando o Claude Code CLI
echo Vou conferir o SHA-256 de uma copia local ou do cache.
call "%~dp0install-cli.cmd"
if not errorlevel 1 goto :cli_installed
echo.
echo Ainda nao temos uma copia pronta para instalar. Vou baixa-la do S3.
echo Esse download tem cerca de 300 MB e pode levar alguns minutos.
call "%~dp0download-s3.cmd" windows-x64 claude-code
if errorlevel 1 goto :failed
call "%~dp0install-cli.cmd"
if errorlevel 1 goto :failed
:cli_installed
"%DEV_ENV_INSTALL_DIR%\claude.exe" --version
if errorlevel 1 (
    echo A CLI foi copiada, mas nao respondeu ao comando de versao.
    echo Verifique com a TI se a execucao desse binario esta liberada.
    goto :failed
)
echo A CLI esta instalada. Agora vamos cuidar da conexao e da sua conta.
echo.
echo [3/6] Preparando o certificado da rede corporativa
echo O certificado permite que a CLI reconheca a conexao HTTPS da empresa.
if defined NODE_EXTRA_CA_CERTS goto :check_certificate
for /f "delims=" %%C in ('cscript.exe //nologo //E:JScript "%~dp0setup-config.js" certificate-path 2^>nul') do set "NODE_EXTRA_CA_CERTS=%%C"
if defined NODE_EXTRA_CA_CERTS goto :check_certificate
if exist "%USERPROFILE%\.local\certs\ca_root.pem" set "NODE_EXTRA_CA_CERTS=%USERPROFILE%\.local\certs\ca_root.pem"
if defined NODE_EXTRA_CA_CERTS goto :check_certificate
:ask_certificate
echo.
echo Informe o caminho de um certificado PEM fornecido pela TI.
echo Pode colar o caminho com aspas. Se sua rede nao exige certificado, digite S.
set "SETUP_CERT_INPUT="
set /p "SETUP_CERT_INPUT=Caminho do certificado ou S: "
if not defined SETUP_CERT_INPUT goto :certificate_cancelled
set "SETUP_CERT_INPUT=%SETUP_CERT_INPUT:"=%"
if /i "%SETUP_CERT_INPUT%"=="S" goto :skip_certificate
set "NODE_EXTRA_CA_CERTS=%SETUP_CERT_INPUT%"
:check_certificate
if not exist "%NODE_EXTRA_CA_CERTS%" (
    echo Nao encontrei o arquivo indicado. Vamos conferir o caminho.
    set "NODE_EXTRA_CA_CERTS="
    goto :ask_certificate
)
rem Pass the path through the environment, never through Bash source text.
"%CLAUDE_CODE_GIT_BASH_PATH%" --noprofile --norc -c "/usr/bin/openssl x509 -in \"$(/usr/bin/cygpath -u \"$NODE_EXTRA_CA_CERTS\")\" -noout" >nul 2>&1
if errorlevel 1 (
    echo Nao consegui ler esse arquivo como certificado PEM.
    echo Solicite a TI a cadeia em PEM. Um arquivo CER em DER precisa de conversao.
    set "NODE_EXTRA_CA_CERTS="
    goto :ask_certificate
)
echo Certificado PEM localizado e lido com sucesso:
echo   "%NODE_EXTRA_CA_CERTS%"
echo O arquivo sera usado pela CLI, sem alterar o repositorio de certificados do Windows.
goto :configure_settings
:skip_certificate
set "NODE_EXTRA_CA_CERTS="
set "DEV_ENV_SKIP_CERTIFICATE=1"
echo Vamos continuar sem certificado adicional. A validacao HTTPS permanece ativa.
:configure_settings
echo.
echo [4/6] Conectando sua conta ao Genial
echo Vou preparar seu settings.json e guardar um backup se ele ja existir.
cscript.exe //nologo //E:JScript "%~dp0setup-config.js" prepare
if errorlevel 1 goto :failed
cscript.exe //nologo //E:JScript "%~dp0setup-config.js" validate >nul 2>&1
if not errorlevel 1 (
    echo Sua API Key ja esta cadastrada. Podemos seguir.
    goto :validate_settings
)
:edit_settings
echo.
echo Vou abrir o Bloco de Notas. Procure ANTHROPIC_AUTH_TOKEN.
echo Troque somente cole-aqui-sua-APIKey-do-Genial pela sua API Key,
echo mantendo as aspas. Salve com Ctrl+S e feche o editor.
echo Sua chave fica no arquivo local e nao sera exibida aqui.
set "SETUP_CONTINUE="
set /p "SETUP_CONTINUE=Pressione Enter para abrir o arquivo ou C para cancelar: "
if /i "%SETUP_CONTINUE%"=="C" goto :cancelled
start "" /wait notepad.exe "%CLAUDE_CONFIG_DIR%\settings.json"
if errorlevel 1 (
    echo Nao consegui abrir o Bloco de Notas. Edite o arquivo abaixo e execute novamente:
    echo   "%CLAUDE_CONFIG_DIR%\settings.json"
    goto :failed
)
cscript.exe //nologo //E:JScript "%~dp0setup-config.js" validate
if not errorlevel 1 goto :validate_settings
echo.
choice /c RC /n /m "Precisamos ajustar o arquivo. R para reabrir ou C para cancelar: "
if errorlevel 2 goto :cancelled
if errorlevel 1 goto :edit_settings
goto :cancelled
:validate_settings
echo.
echo [5/6] Validando e deixando o ambiente pronto
cscript.exe //nologo //E:JScript "%~dp0setup-config.js" validate
if errorlevel 1 goto :failed
if defined SETUP_SESSION_ONLY goto :session_only
echo Vou salvar as variaveis na sua conta do Windows e incluir a CLI no PATH.
cscript.exe //nologo //E:JScript "%~dp0setup-config.js" persist
if errorlevel 1 goto :failed
echo Se novos terminais nao receberem as variaveis, encerre a sessao do Windows e entre novamente.
goto :final_check
:session_only
echo Modo de sessao: as variaveis do Windows e o PATH permanente nao serao alterados.
:final_check
rem Clear inherited routing overrides only inside the setup/current CMD session.
set "ANTHROPIC_API_KEY="
set "NODE_TLS_REJECT_UNAUTHORIZED="
set "CLAUDE_CODE_USE_BEDROCK="
set "CLAUDE_CODE_USE_VERTEX="
set "CLAUDE_CODE_USE_FOUNDRY="
set "CLAUDE_CODE_USE_MANTLE="
set "CLAUDE_CODE_USE_ANTHROPIC_AWS="
echo.
echo [6/6] Conferindo a instalacao e mostrando o proximo passo
echo CLI pronta em: "%DEV_ENV_INSTALL_DIR%\claude.exe"
echo A versao foi conferida na etapa de instalacao.
echo.
echo Pronto! O Claude Code esta configurado neste computador.
echo Para comecar, entre na pasta do seu projeto e execute: claude
echo Configuracao: "%CLAUDE_CONFIG_DIR%\settings.json"
echo A conexao autenticada com o Genial sera feita quando voce usar a CLI.
echo Se uma IDE ja estava aberta, salve seu trabalho e reabra-a.
if defined SETUP_SESSION_ONLY echo As variaveis deste modo valem somente para este CMD.
echo.
endlocal & call "%~dp0env.cmd" & set "CLAUDE_CONFIG_DIR=%CLAUDE_CONFIG_DIR%" & set "NODE_EXTRA_CA_CERTS=%NODE_EXTRA_CA_CERTS%" & set "ANTHROPIC_API_KEY=" & set "NODE_TLS_REJECT_UNAUTHORIZED=" & set "CLAUDE_CODE_USE_BEDROCK=" & set "CLAUDE_CODE_USE_VERTEX=" & set "CLAUDE_CODE_USE_FOUNDRY=" & set "CLAUDE_CODE_USE_MANTLE=" & set "CLAUDE_CODE_USE_ANTHROPIC_AWS="
exit /b 0
:runtime_missing
echo O Windows Script Host ^(cscript/JScript^) precisa estar disponivel para preparar o JSON.
echo Se a empresa bloqueia esse recurso, solicite a liberacao a equipe de TI.
goto :failed
:certificate_cancelled
echo Nenhum caminho foi informado. Execute novamente com o certificado ou escolha S.
goto :cancelled
:cancelled
echo.
echo Configuracao interrompida. Voce pode executar este assistente novamente.
endlocal
exit /b 2
:failed
echo.
echo Nao consegui concluir esta etapa. Veja a orientacao acima e execute novamente.
echo As etapas seguintes nao foram executadas.
endlocal
exit /b 1
:usage
echo Uso: setup.cmd [--session-only]
echo Sem opcao, configura tambem as variaveis de usuario do Windows.
endlocal
exit /b 2
