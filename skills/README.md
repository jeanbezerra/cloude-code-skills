# Skills para Claude Code

## Skills disponíveis

| Skill | Escopo | Recursos incluídos |
| --- | --- | --- |
| `fluent-ui-react` | React com Fluent UI v9 e Microsoft Fluent 2 | Dez referências sobre componentes, tokens, Griffel, temas, migração, SSR, ícones, conteúdo e acessibilidade |
| `fluent2-angular-21` | Angular 21+ com Fluent Web Components, sem runtime React | Nove referências e auditor estático Node.js |

As duas skills foram adaptadas das versões do Codex para Claude Code, com descoberta automática e invocação por comando. Os arquivos usam linguagem genérica e não dependem de caminhos pessoais, MCP ou configurações específicas de uma organização.

### Fluent UI React

`fluent-ui-react/` é a versão da skill de Fluent UI React do Codex adaptada para Claude Code. Preserva as dez referências de componentes, tokens, Griffel, temas, migração, SSR, ícones, conteúdo e acessibilidade. O pacote contém `SKILL.md` com `name`/`description` e os arquivos de referência; os metadados de interface `agents/openai.yaml` do Codex não foram incluídos.

A skill cria, migra, revisa e corrige interfaces React com Fluent UI v9 e Microsoft Fluent 2. A descoberta automática permanece habilitada. Não se aplica a Angular, interfaces nativas ou backend.

### Fluent 2 Angular 21+

`fluent2-angular-21/` preserva as orientações de arquitetura Angular, escolha de componentes, tokens, temas, formulários, layout, conteúdo, ícones, acessibilidade e qualidade. Usa Web Components oficiais e integração Angular; não introduz pacotes Fluent React. O auditor `scripts/audit-fluent2.mjs` usa somente módulos nativos do Node.js e apenas lê o projeto.

## Instalação pelo CMD

Na raiz deste repositório, execute:

```bat
call skills\install.cmd all
```

O comando copia as duas pastas completas para `%USERPROFILE%\.claude\skills`. Não precisa de administrador, PowerShell, Python, Node.js ou npm para instalar as skills. Quando executado novamente, atualiza os arquivos do mesmo nome; não apaga outros arquivos nem altera as configurações do Claude Code.

Para instalar somente uma delas:

```bat
call skills\install.cmd fluent-ui-react
call skills\install.cmd fluent2-angular-21
```

Sem argumentos, o instalador mantém `fluent-ui-react` como padrão.

Para disponibilizá-la somente em um projeto:

```bat
call skills\install.cmd all "C:\caminho\do-projeto\.claude\skills"
```

Se você configurou um diretório pessoal diferente para o Claude Code, informe a pasta `skills` desse diretório como segundo argumento.

## Instalação pelo Git Bash ou Linux

Na raiz deste repositório:

```bash
for skill in fluent-ui-react fluent2-angular-21; do
  mkdir -p "$HOME/.claude/skills/$skill"
  cp -R "./skills/$skill/." "$HOME/.claude/skills/$skill/"
done
```

Alternativamente, copie as pastas das skills para `.claude/skills/` dentro de um projeto. Preserve `references/` e, na Angular, `scripts/`; copiar apenas `SKILL.md` deixa a instalação incompleta. A pasta `skills/` deste repositório é o pacote de distribuição, e precisa ser copiada para uma dessas localizações para ser descoberta.

Esses caminhos e a invocação por `/nome-da-skill` seguem a [documentação oficial de skills do Claude Code](https://code.claude.com/docs/en/skills).

## Uso

Abra o Claude Code no projeto React e invoque:

```text
/fluent-ui-react Crie um formulário de cadastro com Fluent UI v9 e validação acessível.
```

Para revisar React:

```text
/fluent-ui-react Revise src/components quanto a tokens semânticos, composição, teclado e foco.
```

No projeto Angular:

```text
/fluent2-angular-21 Crie um formulário reativo com componentes Fluent oficiais e validação acessível.
```

Se uma skill não aparecer no menu `/`, abra uma nova sessão após a instalação e confirme que existe `SKILL.md` dentro de `~/.claude/skills/fluent-ui-react/` ou `~/.claude/skills/fluent2-angular-21/`, ou na localização equivalente no projeto. A instalação local destina-se ao Claude Code; ela não instala as skills na conta do site ou do aplicativo Desktop.

A execução usa CMD ou Git Bash no Windows. A instalação da skill não instala dependências de projetos nem concede permissões adicionais. Para implementar e validar interfaces, utiliza o gerenciador de pacotes, as versões e as ferramentas realmente disponíveis no projeto. Quando o acesso à documentação estiver limitado, deve usar os tipos e referências locais disponíveis e relatar o que não conseguiu validar.

## Auditor Angular opcional

Com Node.js já disponível, execute no CMD, informando o projeto a revisar:

```bat
node "%USERPROFILE%\.claude\skills\fluent2-angular-21\scripts\audit-fluent2.mjs" --project "C:\caminho\do-projeto" --json
```

O auditor não instala dependências nem modifica o projeto. Ele procura fontes em `src`; ajuste com `--source` quando necessário. O relatório é heurístico: confira a versão resolvida, o CEM, os imports e o contexto antes de concluir que há erro. Instalações sem `node_modules` físico podem exigir verificação manual. Build, testes de navegador, teclado e inspeção visual continuam sendo verificações próprias do projeto.
