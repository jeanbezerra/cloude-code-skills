# Acessibilidade

A meta é WCAG 2.2 AA para o escopo suportado pelo produto.

## Gate mínimo

- HTML semântico e headings em ordem lógica;
- operação completa por teclado e foco visível;
- ordem de foco coerente e retorno de foco após dialog/drawer;
- nomes, roles, states e relationships corretos;
- contraste de 4,5:1 para texto comum, 3:1 para texto grande e 3:1 para controles/indicadores;
- zoom de texto a 200% e zoom da página a 400% sem bloquear tarefas no viewport suportado;
- `prefers-reduced-motion` e forced colors quando aplicáveis;
- estados loading, empty, error, disabled, readonly, required e invalid perceptíveis;
- live region apenas para mudanças que precisam ser anunciadas.

Não adicione ARIA que duplique ou contradiga semântica nativa. Use `aria-sort` em cabeçalho de tabela ordenável, não no botão. Botões icon-only precisam de nome acessível; ícones decorativos usam `aria-hidden="true"`.

## Visualizações de dados

- Forneça título e explicação do gráfico.
- Não dependa somente da cor; use labels, padrões, símbolos ou texto.
- Preserve legenda e área de plotagem sem sobreposição.
- Para dados relevantes ao laudo, ofereça resumo textual ou tabela equivalente quando viável.
- Teste tooltip/foco sem mudar a legibilidade no tema ativo.

## Validação

Combine inspeção de DOM, teclado, contraste, zoom e ferramenta automatizada quando disponível. Axe não substitui teste manual; ausência de Playwright/axe deve ser informada, não inventada.
