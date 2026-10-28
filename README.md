# Claude Code no Windows

Abra o **Prompt de Comando (CMD)** na pasta deste projeto e execute:

```bat
call configurar.cmd
```

O assistente explica o que está fazendo e acompanha você em seis etapas:

1. **Encontrar o Git Bash.** Localiza a instalação automaticamente, incluindo instalações por usuário e caminhos fora do padrão.
2. **Instalar o Claude Code CLI.** Confere o SHA-256 e usa o pacote local ou o cache; baixa do S3 quando necessário. A instalação acontece antes da configuração do Genial.
3. **Configurar o certificado corporativo.** Reutiliza o certificado configurado ou orienta você a informar o arquivo fornecido pela TI. É possível pular quando ele não for necessário.
4. **Configurar o Genial.** Prepara o `settings.json`, preserva as opções existentes e cria um backup. Se ainda não houver uma chave cadastrada, você informa sua API Key no Bloco de Notas, sem colá-la no CMD.
5. **Validar e salvar o ambiente.** Confere a configuração e ajusta as variáveis e o PATH da sua conta, sem administrador.
6. **Concluir e começar a usar.** Mostra o resultado da instalação e como abrir o Claude Code.

Tenha o Git for Windows instalado e sua API Key do Genial em mãos. O fluxo usa CMD, Windows Script Host (`cscript`), Git Bash, `curl` e `certutil`; não precisa de PowerShell, Node.js, npm, Python ou AWS CLI. Se o Windows Script Host estiver bloqueado, peça à TI a liberação desse componente para executar o assistente.

Para configurar apenas a sessão atual, sem salvar variáveis no Windows:

```bat
call configurar.cmd --session-only
```

Esse modo ainda salva o `settings.json` e seus backups. O ambiente preparado vale para o CMD atual.

Consulte o [guia completo de configuração](dev-env/README.md) para personalizar diretórios, certificados ou downloads, e o [guia de skills](skills/README.md) para instalar as skills React e Angular. O Claude Desktop e as skills têm instalação separada.
