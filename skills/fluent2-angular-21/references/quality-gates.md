# Gates de qualidade

## Descoberta

Leia `package.json` e use somente scripts existentes. Em geral, priorize:

1. format/lint;
2. typecheck/build;
3. testes unitários afetados;
4. E2E e axe existentes;
5. inspeção visual e teclado proporcional ao risco.

Não instale Playwright, axe ou outro pacote apenas para satisfazer a checklist sem autorização. Se a infraestrutura não existe, execute os gates disponíveis e registre a lacuna.

## Matriz proporcional

| Alteração | Verificação mínima |
| --- | --- |
| CSS/texto pequeno | format/lint, build e inspeção visual |
| Controle interativo | anterior + teclado, foco, valor inicial, eventos, disabled |
| Formulário | anterior + validação, touched, submissão e mensagens |
| Tema/tokens | temas solicitados + contraste + forced colors quando suportado |
| Layout responsivo | viewports declarados + zoom |
| SSR/hydration | build SSR/prerender + hidratação no navegador |
| Fluxo crítico | testes automatizados existentes + cenário manual representativo |

## Auditor da skill

Execute:

```bash
node "${CLAUDE_SKILL_DIR}/scripts/audit-fluent2.mjs" --project .
```

No Claude Code, `${CLAUDE_SKILL_DIR}` é substituído pelo caminho da skill instalada. Fora dele, use o caminho real do arquivo. Execute o auditor na raiz do pacote Angular correto; use `--source` quando as fontes estiverem fora de `src`, mantendo a leitura dentro do escopo do projeto.

Os resultados são indícios para revisão contextual, como dependência React em uma integração Angular ou uma tag não localizada na instalação. O auditor não altera arquivos nem instala pacotes. `--json` produz saída estruturada; `--strict` também retorna falha quando há avisos.

Confirme o diagnóstico antes de corrigir: a versão Angular é inferida do texto em `package.json`, não da versão resolvida no lockfile; buscas por regex podem incluir comentários e não detectar registro ou tema fora das fontes selecionadas. A consulta a CEM e módulos espera `node_modules` físico. Em instalações Plug'n'Play, resolva o pacote pelo gerenciador ou registre a limitação, sem concluir que uma tag é inexistente somente pelo relatório. Avisos não autorizam correções mecânicas nem uma migração fora do pedido.

## Resultado de conformidade

- `CONFORME`: todos os requisitos aplicáveis ao escopo foram implementados e validados.
- `CONFORME COM EXCEÇÕES`: há lacuna aplicável, teste indisponível ou decisão divergente documentada.
- `NÃO CONFORME`: build quebrado, erro confirmado do auditor não resolvido ou requisito aplicável violado.

Um tema ou viewport explicitamente fora do escopo não é exceção.
