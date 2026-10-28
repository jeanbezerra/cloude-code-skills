# Ambiente Claude — CMD, Git Bash e Linux

Kit preparado em **27/10/2026**, com downloads oficiais da Anthropic para **x64**. Claude Code é a CLI; a interface gráfica é o **Claude Desktop**, que inclui a aba Code. Os scripts de uso no ambiente de destino não executam PowerShell e não exigem Node.js, npm, Python ou AWS CLI.

## Arquivos já baixados

| Produto | Sistema | Versão | Arquivo em `artifacts/` | Tamanho |
| --- | --- | --- | --- | --- |
| Claude Code CLI, canal stable | Windows x64 | 2.1.308 | `claude-code/2.1.308/windows-x64/claude-code-2.1.308-windows-x64.exe` | 297.376.928 bytes |
| Claude Code CLI, canal stable | Linux x64, glibc | 2.1.308 | `claude-code/2.1.308/linux-x64/claude-code-2.1.308-linux-x64` | 292.232.560 bytes |
| Claude Desktop | Windows x64 | 3.6556.2.0 | `claude-desktop/3.6556.2.0/windows-x64/claude-desktop-3.6556.2.0-windows-x64.msix` | 284.230.330 bytes |
| Claude Desktop, beta | Linux amd64 | 3.6556.2 | `claude-desktop/3.6556.2/linux-x64/claude-desktop-3.6556.2-linux-x64.deb` | 169.811.528 bytes |

Total: **1.043.651.346 bytes**, aproximadamente 1,04 GB. Os binários estão nesta pasta, mas são ignorados pelo Git por tamanho. O S3 distribui somente esses quatro binários. Scripts, catálogo, hashes, configurações e documentação permanecem locais. ARM64 e Alpine/musl não fazem parte deste kit.

Publicado em **27/10/2026**: os quatro binários foram baixados por HTTPS sem credenciais, com tamanho e SHA-256 conferidos. Nenhum script ou arquivo auxiliar permanece no prefixo S3. O catálogo e os comandos acompanham este projeto no Git.

Os binários seguem a estrutura `artifacts/<product_id>/<version>/<platform>/<product_id>-<version>-<platform><ext>`, com `product_id` igual a `claude-code` ou `claude-desktop` e `platform` igual a `windows-x64` ou `linux-x64`. Os nomes usam somente ASCII em minúsculas, na ordem produto-versão-sistema-arquitetura. A CLI Linux não tem extensão; os demais usam `.exe`, `.msix` ou `.deb`. Os nomes dos scripts existentes, `README.md` e `SHA256SUMS` foram mantidos.

`artifacts/manifest.json` registra versões, URLs de origem, tamanhos e SHA-256; `artifacts/SHA256SUMS` contém os hashes. A CLI e o `.deb` foram conferidos com os manifests/índices oficiais. O SHA-256 do MSIX foi calculado após download HTTPS do endpoint oficial. Nenhum aplicativo foi instalado durante a preparação.

## Começar no Windows usando CMD

Abra o **Prompt de Comando (CMD)** na raiz deste projeto e execute:

```bat
call configurar.cmd
```

Se você já estiver na pasta `dev-env`, use `call setup.cmd`. O assistente apresenta seis etapas, explica cada ação e interrompe o processo com uma orientação se encontrar um problema. Tenha sua API Key do Genial em mãos e, quando exigido pela rede corporativa, o certificado fornecido pela TI.

### 1. Encontrar o Git Bash

O assistente procura o Git for Windows nas pastas usuais, nas instalações por usuário, no Registro e no PATH. Ele valida o Bash encontrado e evita confundi-lo com o Bash do WSL. Você não precisa substituir sua matrícula em um caminho nem escrever barras invertidas duplicadas.

Se o Git não estiver instalado, instale o Git for Windows pelo canal disponibilizado pela empresa e execute o assistente novamente. Para informar uma instalação específica, defina antes:

```bat
set "CLAUDE_CODE_GIT_BASH_PATH=C:\caminho\Git\bin\bash.exe"
call configurar.cmd
```

Um caminho definido manualmente tem prioridade: se estiver incorreto, o assistente explica como corrigir.

### 2. Instalar o Claude Code CLI

A CLI é instalada antes de configurar a conexão com o Genial. O assistente aproveita o binário do kit ou o cache quando disponível e confere o SHA-256. Quando necessário, baixa somente a CLI Windows x64 do S3 e valida o arquivo antes da instalação.

O destino padrão é `%LOCALAPPDATA%\ClaudeDevEnv\bin`. A instalação não exige administrador e não executa o instalador online da Anthropic. Claude Desktop e skills ficam fora desta etapa; suas instruções estão nas seções específicas deste guia e no [guia de skills](../skills/README.md).

### 3. Informar o certificado corporativo

O assistente aproveita `NODE_EXTRA_CA_CERTS`, quando configurado, ou procura `%USERPROFILE%\.local\certs\ca_root.pem`. Se precisar informar outro arquivo, use o caminho do certificado em formato PEM fornecido pela TI e acompanhe a validação com o OpenSSL do Git Bash. Um arquivo `.cer` também precisa conter o certificado em formato PEM; se você recebeu um CER em formato DER, peça a versão PEM à TI. Quando o certificado não for necessário no seu ambiente, escolha **S** para pular esta etapa.

O caminho aceito é incluído na configuração e nas variáveis da sua conta. O assistente não extrai certificados de sites externos e mantém a validação TLS habilitada. Veja a [documentação de rede corporativa e certificados](https://code.claude.com/docs/en/network-config).

### 4. Preparar a configuração do Genial

O assistente prepara `%USERPROFILE%\.claude\settings.json`, ou o diretório informado em `CLAUDE_CONFIG_DIR`. As opções existentes são preservadas e um backup é criado antes de alterar o arquivo. Se o JSON estiver inválido, a configuração para para você corrigir o arquivo original.

Se a chave ainda não estiver cadastrada, o Bloco de Notas abre para você preencher `ANTHROPIC_AUTH_TOKEN` com sua API Key do Genial. Salve o arquivo e feche o editor para continuar. Se a chave já estiver cadastrada, o assistente confirma isso sem revelar seu valor. Se a configuração anterior apontava para outro gateway, o assistente pede a chave do Genial novamente e preserva o arquivo anterior no backup. Essa conferência verifica a presença da chave, sem testar sua aceitação pelo serviço. A chave não é solicitada no CMD nem exibida nas mensagens do assistente; permanece no arquivo local de configuração e nos seus backups.

O endereço sugerido pelas fotos é `https://genial-lite.plataforma-gen-ia.prd.awsporto`. Esse endereço depende da rede e das permissões corporativas; a configuração local não comprova acesso ao serviço. Para usar outro endereço autorizado, defina `DEV_ENV_GENIAL_URL` antes de executar o assistente.

Também são configurados o Git Bash detectado, a desativação da ferramenta PowerShell e os controles de atualização e telemetria do procedimento. Variáveis de autenticação e seleção de provedores que conflitem com esse fluxo são identificadas pelo nome, sem revelar valores de credenciais. A estrutura de `env` segue a [documentação de variáveis do Claude Code](https://code.claude.com/docs/en/env-vars).

### 5. Validar e salvar o ambiente

O assistente confere o JSON, a presença da chave, o endereço HTTPS, o Git Bash e o caminho do certificado, quando informado. Também ajusta `CLAUDE_CONFIG_DIR`, `CLAUDE_CODE_GIT_BASH_PATH`, `CLAUDE_CODE_USE_POWERSHELL_TOOL`, os controles de atualização e o PATH da sua conta. O PATH existente é preservado, sem usar `setx` para regravá-lo.

As alterações persistentes ficam na conta do usuário e não exigem administrador. Se uma variável conflitante estiver definida no nível da máquina, siga a orientação exibida para solicitar o ajuste à TI.

Para salvar os arquivos de configuração e preparar somente a sessão atual, sem alterar as variáveis persistentes do Windows, execute:

```bat
call configurar.cmd --session-only
```

Nesse modo, o CMD atual recebe o ambiente ao concluir. Em outro CMD, execute o assistente novamente ou carregue `env.cmd` com as mesmas personalizações. Se você usa `CLAUDE_CONFIG_DIR` fora do padrão, defina essa variável antes: `env.cmd` não recupera o diretório personalizado automaticamente.

### 6. Concluir e usar o Claude Code

Ao terminar, o assistente mostra a instalação encontrada e a verificação da versão. No CMD preparado, acesse a pasta do seu projeto e execute:

```bat
cd /d "C:\caminho\do-projeto"
claude
```

O CMD em que o assistente foi executado já recebe o ambiente preparado. Após salvar variáveis persistentes, reabra terminais e IDEs que já estavam em execução. Se o Windows ainda fornecer o ambiente antigo aos novos aplicativos, encerre sua sessão do Windows e entre novamente: a gravação das variáveis não notifica o Explorer automaticamente. A verificação de versão e dos arquivos locais não envia uma solicitação ao Genial nem garante acesso aos modelos.

### Requisitos e personalização

O assistente usa CMD, Windows Script Host (`cscript`), Git Bash, `curl` e `certutil`. Não precisa de PowerShell, Node.js, npm, Python ou AWS CLI. Se o Windows Script Host estiver bloqueado por política corporativa, peça à TI a liberação desse componente antes de continuar.

Para distribuir o kit, copie os scripts e `artifacts/catalog.txt` mantendo a estrutura de pastas. O bucket padrão é `jb-static-files-177862772785-sa-east-1-an`, na região `sa-east-1`, com prefixo `dev-env`; ele distribui somente os quatro binários da tabela.

Para personalizar diretórios, proxy ou prefixo, copie `env.local.cmd.example` para `env.local.cmd` e ajuste as opções desejadas. Ao mudar `S3_PREFIX`, remova uma eventual `S3_BASE_URL` fixada, pois a URL completa tem prioridade sobre a composição por bucket, região e prefixo.

### Comandos manuais de download e instalação

Se quiser executar apenas a instalação da CLI, sem o assistente de configuração:

```bat
call env.cmd
call download-s3.cmd windows-x64 claude-code
call install-cli.cmd
call env.cmd
claude --version
```

Se o kit já contiver o binário, você pode executar `call install-cli.cmd` sem baixá-lo novamente. Esses comandos individuais usam o PATH da sessão e não persistem as variáveis do Windows; a persistência faz parte do assistente `setup.cmd`.

Para baixar os dois produtos, use `call download-s3.cmd windows-x64 all`. Os arquivos recebidos ficam em `downloads\artifacts\...`. O downloader também aceita pacotes Linux no Windows: `call download-s3.cmd linux-x64 all`.

## Download direto pelo CMD

Os comandos abaixo baixam diretamente cada binário para a pasta atual. Execute apenas os correspondentes ao produto e sistema desejados:

```bat
set "S3_BASE_URL=https://jb-static-files-177862772785-sa-east-1-an.s3.sa-east-1.amazonaws.com/dev-env"
curl.exe --fail --location --proto "=https" --proto-redir "=https" "%S3_BASE_URL%/artifacts/claude-code/2.1.308/windows-x64/claude-code-2.1.308-windows-x64.exe" -o "claude-code-2.1.308-windows-x64.exe"
curl.exe --fail --location --proto "=https" --proto-redir "=https" "%S3_BASE_URL%/artifacts/claude-desktop/3.6556.2.0/windows-x64/claude-desktop-3.6556.2.0-windows-x64.msix" -o "claude-desktop-3.6556.2.0-windows-x64.msix"
curl.exe --fail --location --proto "=https" --proto-redir "=https" "%S3_BASE_URL%/artifacts/claude-code/2.1.308/linux-x64/claude-code-2.1.308-linux-x64" -o "claude-code-2.1.308-linux-x64"
curl.exe --fail --location --proto "=https" --proto-redir "=https" "%S3_BASE_URL%/artifacts/claude-desktop/3.6556.2/linux-x64/claude-desktop-3.6556.2-linux-x64.deb" -o "claude-desktop-3.6556.2-linux-x64.deb"
```

Confira cada SHA-256 com `certutil -hashfile "nome-do-arquivo" SHA256` e compare com a cópia local de `artifacts/SHA256SUMS`. Para download com validação automática e instalação por cópia, use os scripts locais:

```bat
call env.cmd
call download-s3.cmd windows-x64 claude-code
call install-cli.cmd
claude --version
```

## Git Bash e Linux

Em ambos, use Bash, `curl` e `sha256sum` disponíveis no PATH:

```bash
export S3_BASE_URL="https://jb-static-files-177862772785-sa-east-1-an.s3.sa-east-1.amazonaws.com/dev-env"
source ./env.sh
bash ./download-s3.sh
bash ./install-cli.sh
claude --version
```

Sem argumentos, o downloader detecta Windows/Git Bash ou Linux e baixa os dois produtos. Também aceita `bash ./download-s3.sh linux-x64 claude-code`. O diretório padrão da CLI é `~/.local/bin` no Linux e `%LOCALAPPDATA%/ClaudeDevEnv/bin` no Git Bash. Para personalizar, copie `env.local.sh.example` para `env.local.sh`. Carregue `source /caminho/dev-env/env.sh` em cada nova sessão.

Para conferir manualmente todos os arquivos da cópia original, execute da raiz `dev-env`: `sha256sum -c artifacts/SHA256SUMS`.

## Instalar o Desktop

**Windows:** o MSIX é o pacote completo, adequado para espelhar no S3. Requer Windows build 19041+ e instalação administrativa ou provisionamento corporativo. Abra o arquivo pelo App Installer, se autorizado no ambiente:

```bat
start "" "%DEV_ENV_DOWNLOAD_DIR%\artifacts\claude-desktop\3.6556.2.0\windows-x64\claude-desktop-3.6556.2.0-windows-x64.msix"
```

O serviço Cowork incluído no MSIX impede instalação por usuário sem elevação. Os scripts deste kit não elevam privilégios nem executam PowerShell. Veja a [orientação oficial de implantação Windows](https://support.claude.com/en/articles/12622703-deploy-claude-desktop-for-windows).

**Linux:** o Desktop beta suporta Ubuntu 22.04+ e Debian 12+. Antes de instalar, se quiser manter a distribuição exclusivamente pelo seu canal, configure `/etc/default/claude-desktop` com `CLAUDE_DESKTOP_ADD_REPO="false"`, preservando configurações existentes. Depois:

```bash
sudo apt install "$DEV_ENV_DOWNLOAD_DIR/artifacts/claude-desktop/3.6556.2/linux-x64/claude-desktop-3.6556.2-linux-x64.deb"
```

O `apt` pode precisar dos repositórios da distribuição para dependências. A [documentação oficial Linux](https://code.claude.com/docs/en/desktop-linux) detalha requisitos e o registro automático do repositório Anthropic.

## Variáveis do ambiente

| Variável | Finalidade / padrão |
| --- | --- |
| `S3_BASE_URL` | URL HTTPS completa do prefixo; tem prioridade sobre a composição abaixo |
| `S3_BUCKET` | Bucket configurado: `jb-static-files-177862772785-sa-east-1-an` |
| `S3_REGION` | Região; padrão `sa-east-1` |
| `S3_PREFIX` | Prefixo; padrão `dev-env`, sem barras nas extremidades |
| `DEV_ENV_HOME` | Diretório deste kit |
| `DEV_ENV_CATALOG` | Catálogo local; padrão `dev-env/artifacts/catalog.txt` |
| `DEV_ENV_DOWNLOAD_DIR` | Cache de downloads; padrão `dev-env/downloads` |
| `DEV_ENV_INSTALL_DIR` | Diretório da CLI, incluído no PATH da sessão |
| `DEV_ENV_GENIAL_URL` | Endereço do gateway Genial usado pelo assistente; padrão das fotos: `https://genial-lite.plataforma-gen-ia.prd.awsporto` |
| `CLAUDE_CONFIG_DIR` | Diretório de configuração do Claude Code; padrão `%USERPROFILE%\.claude` |
| `NODE_EXTRA_CA_CERTS` | Caminho do certificado corporativo adicional, quando necessário |
| `AWS_CLI_EXE` | Opcional, caminho do AWS CLI na máquina de publicação; detectado no PATH ou na instalação padrão |
| `CLAUDE_CODE_GIT_BASH_PATH` | Caminho Windows do `bash.exe` do Git for Windows |
| `CLAUDE_CODE_USE_POWERSHELL_TOOL` | `0`: desativa a ferramenta PowerShell do Claude Code |
| `DISABLE_AUTOUPDATER` / `DISABLE_UPDATES` | `1`: mantém a CLI no canal de distribuição deste kit |
| `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY` | Opcionais, conforme o proxy corporativo |

Esses controles da CLI seguem a [referência oficial de variáveis](https://code.claude.com/docs/en/env-vars). As políticas de atualização do **Desktop** são separadas. O download pelo S3 resolve a distribuição dos instaladores; login e uso ainda precisam de acesso aos serviços autorizados pela empresa. Nenhuma chave de API ou credencial AWS é necessária para o download público.

## Preparar o bucket S3

Use o bucket de ARN `arn:aws:s3:::jb-static-files-177862772785-sa-east-1-an`, na região `sa-east-1`, e publique somente os quatro caminhos de binários da tabela, sob `s3://jb-static-files-177862772785-sa-east-1-an/dev-env/artifacts/`. O catálogo, os hashes, os scripts e os exemplos de ambiente ficam na cópia local do kit. Use o endpoint HTTPS de objetos mostrado acima; não é necessário habilitar hospedagem de website nem CORS para CMD/curl.

O arquivo local `s3-public-read-policy.json`, já aplicado, permite leitura pública por HTTPS somente nas pastas de binários `artifacts/claude-code/` e `artifacts/claude-desktop/`. Se escolher outro prefixo, ajuste tanto `S3_PREFIX` quanto os recursos da política. Listagem e escrita anônimas não foram liberadas por essa política. Referência: [permissões de leitura pública no S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteAccessPermissionsReqd.html).

Para publicar pelos comandos abaixo, use o AWS CLI instalado na máquina de publicação com credenciais de escrita no bucket. Os padrões são `S3_BUCKET=jb-static-files-177862772785-sa-east-1-an`, `S3_REGION=sa-east-1` e `S3_PREFIX=dev-env`; use `env.local.cmd` somente para personalizações. Revise e publique:

```bat
call publish-s3.cmd --dryrun
call publish-s3.cmd
```

Esse comando publica somente os binários referenciados no catálogo local, após conferir seus hashes. Não envie a pasta `dev-env` inteira nem o catálogo pela console S3: selecione apenas os quatro binários e mantenha seus caminhos. Os computadores de destino usam HTTPS/curl para recebê-los; o suporte de execução permanece local.

Os objetos usam criptografia SSE-S3/AES256 e a publicação não apaga objetos existentes. Para a operação contínua, use credenciais de publicação com acesso limitado a esse prefixo; recomendo logs de acesso do S3, eventos de dados do CloudTrail e métricas do CloudWatch, com destinos de log criptografados. Esses recursos de observabilidade não foram ativados por este kit. Consulte [monitoramento do S3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/monitoring-overview.html) e [preços do S3](https://aws.amazon.com/s3/pricing/) para custos de armazenamento, requisições e transferência.

## Integridade e manutenção

`download-s3` lê o catálogo local, seleciona produto/sistema, baixa somente os binários do bucket, grava em `.part` e só substitui o arquivo após validar SHA-256. Em erro HTTP ou hash divergente, retorna código diferente de zero e preserva a cópia anterior. Uma cópia do catálogo local acompanha o cache em `downloads/artifacts/catalog.txt`. Proteja a integridade dos scripts e do catálogo na distribuição local: eles fornecem a referência para conferir os binários recebidos.

`upstream/` guarda os instaladores oficiais de referência; eles podem acessar a Anthropic e não são usados pelo fluxo S3. Para atualizar os pacotes e o catálogo, somente na máquina mantenedora com Python 3.11+ e acesso às origens:

```bat
python tools\fetch-cli.py
python tools\fetch-desktop.py
python tools\build-catalog.py
```

Revise as versões da tabela, publique somente os binários e distribua o catálogo atualizado junto com o kit local. A CLI Linux deste kit usa glibc; outras arquiteturas/libcs exigem artefatos próprios.

Para validar novamente os downloads públicos completos, execute `python tools\verify-published.py` na máquina mantenedora. O verificador lê o manifesto local e confere os quatro SHA-256 usando HTTPS sem credenciais; cada execução transfere aproximadamente 1,04 GB do S3.

Os testes abaixo são executados na pasta `dev-env`, somente na máquina mantenedora:

```bat
python tools\verify-workflow.py
python tools\verify-setup.py
node tools\verify-config-persistence.js
```

`verify-workflow.py` usa um catálogo local e simula os downloads S3 em HTTPS com arquivos sintéticos, cobrindo instalação por cópia, hashes incorretos, HTTP 404, seletores inválidos, Git Bash ausente e diretórios com espaços. Precisa de Python, Git for Windows e seu OpenSSL. O fluxo em Linux real não foi executado nesta máquina Windows.

`verify-setup.py` confere a preservação das opções, da chave e de texto Unicode, backups, JSON inválido e validações sem exposição de credenciais. Também executa o assistente em seis etapas em uma cópia temporária, incluindo Bash em `usr\bin`, caminhos de certificado entre aspas com espaços e caracteres especiais, remoção de um certificado antigo ao escolher **S** e interrupção após falha de instalação. Usa uma CLI de teste e desativa explicitamente editor e persistência na cópia do assistente.

`verify-config-persistence.js` valida a persistência com arquivos e Registro simulados. O Node.js é necessário somente para esse teste do mantenedor; não é uma dependência do assistente. Esses testes não executam Claude, não abrem o editor e não alteram o Registro nem o repositório de certificados do Windows.
