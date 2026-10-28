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

O bucket deste kit é `jb-static-files-177862772785-sa-east-1-an`, com região configurada como `sa-east-1` e prefixo `dev-env`. Ele armazena somente os quatro instaladores/binários da tabela. Para usar os comandos automatizados, copie os scripts e `artifacts/catalog.txt` desta pasta para a máquina de destino, mantendo a estrutura local do kit.

Na pasta local `dev-env`, carregue o endpoint e baixe os dois produtos:

```bat
set "S3_BASE_URL=https://jb-static-files-177862772785-sa-east-1-an.s3.sa-east-1.amazonaws.com/dev-env"
call env.cmd
call download-s3.cmd windows-x64 all
```

Somente a CLI:

```bat
call download-s3.cmd windows-x64 claude-code
call install-cli.cmd
call env.cmd
claude --version
```

O instalador da CLI copia o binário validado para `%LOCALAPPDATA%\ClaudeDevEnv\bin`, sem administrador e sem executar o instalador online da Anthropic. Se você já recebeu esta pasta com os binários, pode executar `call install-cli.cmd` sem baixar novamente. O Git for Windows deve estar instalado: `env.cmd` procura seu `bash.exe`, ou você define `CLAUDE_CODE_GIT_BASH_PATH`.

Os arquivos baixados ficam em `downloads\artifacts\...`. O comando também pode baixar os pacotes Linux no Windows: `call download-s3.cmd linux-x64 all`.

Os padrões já apontam para esse bucket e para o prefixo `dev-env`. Para personalizar diretórios, proxy ou prefixo, copie `env.local.cmd.example` para `env.local.cmd` e ajuste as opções desejadas. Ao mudar `S3_PREFIX`, remova uma eventual `S3_BASE_URL` fixada, pois a URL completa tem prioridade sobre a composição por bucket, região e prefixo. Em cada nova janela CMD, execute `call "C:\caminho\dev-env\env.cmd"` para carregar as variáveis e o PATH. Os scripts não alteram o registro nem o PATH permanente.

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

O teste de integração de manutenção é `python tools\verify-workflow.py`. Ele usa um catálogo local e simula os downloads S3 em HTTPS com arquivos sintéticos, cobrindo instalação por cópia, hashes incorretos, HTTP 404, seletores inválidos, Git Bash ausente e diretórios com espaços. Não executa Claude nem instala certificados no Windows. Precisa de Python, Git for Windows e seu OpenSSL apenas na máquina de testes. O fluxo em Linux real não foi executado nesta máquina Windows.
