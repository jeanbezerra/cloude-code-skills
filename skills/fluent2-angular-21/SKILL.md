---
name: fluent2-angular-21
description: Crie, migre, revise ou corrija interfaces Angular 21+ com Microsoft Fluent 2 usando Web Components, tokens e ícones oficiais, com integração Angular-native e acessibilidade. Não use para React, WinUI, aplicativos nativos ou tarefas somente de backend.
---

# Fluent 2 para Angular 21+

Implemente Fluent 2 em aplicações Angular 21 ou superior sem introduzir runtime React e sem ampliar o escopo definido pelo usuário.

## Execução no Claude Code

- Aplique esta skill quando a tarefa corresponder à descrição ou quando o usuário invocar `/fluent2-angular-21`. Use o pedido e os arquivos informados na conversa como escopo.
- Resolva os links `references/` e `scripts/` a partir da pasta instalada desta skill, não da raiz do projeto. Leia as referências indicadas antes de tomar as decisões correspondentes.
- No Windows, use CMD ou Git Bash. Não execute PowerShell nem `pwsh`. Esta skill não exige MCP, hooks ou serviços externos próprios e não concede permissões adicionais.
- Se a documentação externa ou os testes de navegador estiverem indisponíveis, use o CEM, os tipos e recursos locais e registre a limitação; não invente APIs nem apresente verificações não executadas como aprovadas.

## Contrato essencial

- Preserve requisitos explícitos de plataforma, tema, viewport, biblioteca e escopo. Light-only, desktop-only ou outra restrição deliberada não é uma falha de conformidade.
- Verifique as versões realmente instaladas e o `custom-elements.json` do pacote antes de assumir tags, atributos, eventos ou composição.
- Prefira, nesta ordem: Web Component Fluent oficial, HTML semântico, componente **Fluent-aligned custom**.
- Use `@fluentui/web-components` para componentes, `@fluentui/tokens` para temas/tokens e `@fluentui/svg-icons` para SVGs oficiais quando esses recursos fizerem parte da tarefa.
- Não importe `@fluentui/react*`, `@fluentui/react-icons` nem outro runtime React.
- Não declare conformidade total quando houver erro, requisito aplicável não validado ou exceção não documentada.

## Referências

Leia sempre:

- [Arquitetura Angular](references/architecture-angular.md)
- [Decisão de componentes](references/component-decision-table.md)
- [Acessibilidade](references/accessibility.md)
- [Gates de qualidade](references/quality-gates.md)

Leia somente quando aplicável:

- Tema, cor, tipografia ou CSS: [Tokens e temas](references/tokens-theming.md)
- Formulários, inputs ou wrappers: [Componentes e formulários](references/components-forms.md)
- Shell, grid, navegação, responsividade ou conteúdo: [Layout e conteúdo](references/layout-content.md)
- Ícones: [Iconografia](references/iconography.md)
- Atualização de dependências ou dúvida sobre APIs: [Fontes oficiais](references/source-index.md)

## Fluxo de trabalho

1. Inspecione `package.json`, lockfile, versão Angular, arquitetura standalone/NgModule, SSR/hydration, estilos globais, testes e bibliotecas existentes.
2. Confirme o escopo pedido. Não adicione dark theme, suporte mobile, rotas, pacotes ou componentes que o usuário excluiu ou não autorizou.
3. Se usar Web Components, confira `node_modules/@fluentui/web-components/custom-elements.json` e os módulos exportados pela versão instalada.
4. Importe apenas os elementos usados em um registro carregado antes do bootstrap. Restrinja `CUSTOM_ELEMENTS_SCHEMA` aos wrappers que hospedam custom elements.
5. Implemente wrappers Angular tipados com `ChangeDetectionStrategy.OnPush`, signals e `input()`/`output()` quando isso melhorar a integração. Use `ControlValueAccessor` somente quando o controle participar de Angular Forms.
6. Para elementos compostos ou assíncronos, respeite a ordem de definição, conexão e projeção dos filhos. Sincronize valor inicial após o elemento estar pronto quando a simples property binding não bastar.
7. Aplique tokens semânticos e preserve HTML nativo, teclado, foco, estados e nomes acessíveis.
8. Valide de forma proporcional ao risco e aos scripts disponíveis no projeto. Não invente comandos ausentes nem transforme gates fora de escopo em bloqueios.

## Auditoria opcional da skill

Quando houver um projeto local, execute o auditor estático e depois os comandos reais do projeto:

```bash
node "${CLAUDE_SKILL_DIR}/scripts/audit-fluent2.mjs" --project .
```

O auditor não substitui build, testes, inspeção por teclado, contraste, axe ou validação visual.

O Claude Code substitui `${CLAUDE_SKILL_DIR}` pelo diretório desta skill. Fora do Claude Code, informe o caminho real do arquivo. O auditor usa apenas módulos nativos do Node.js, lê os arquivos do projeto e não os modifica.

## Entrega

Ao concluir uma alteração de interface, informe de forma breve:

```text
Fluent 2 compliance
- Componentes oficiais usados:
- Primitivas HTML usadas:
- Fluent-aligned custom:
- Tokens e temas:
- Ícones:
- Layout e responsividade:
- Acessibilidade:
- Testes executados:
- Exceções ou bloqueios:
- Resultado: CONFORME | CONFORME COM EXCEÇÕES | NÃO CONFORME
```

Use `CONFORME` quando todos os requisitos aplicáveis ao escopo foram implementados e validados. Modos ou viewports explicitamente fora do escopo não contam como exceção.
