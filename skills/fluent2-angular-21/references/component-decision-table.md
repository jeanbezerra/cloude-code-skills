# Decisão de componentes

Escolha a implementação pela primeira linha aplicável.

| Situação | Escolha | Regras |
| --- | --- | --- |
| A versão instalada oferece o componente e ele atende ao comportamento | Web Component Fluent oficial | Validar tag, módulos, filhos, propriedades e eventos no CEM local; criar wrapper Angular quando útil |
| HTML possui semântica e comportamento adequados | Primitiva HTML | Preservar elemento nativo, foco e teclado; estilizar com tokens Fluent |
| Não existe componente oficial adequado | Fluent-aligned custom | Implementar somente a lacuna; documentar semântica, teclado, estados e tokens |
| O componente existe apenas em React | HTML ou custom | Não adicionar React para imitar paridade inexistente no Angular |

## Exemplos

- Tabela de dados: `<table>`, `<th>`, `<button>` para ordenação e paginação; não invente um DataGrid se o pacote instalado não o oferece.
- Link de navegação: `<a>` ou `RouterLink`; não use botão para navegação.
- Ação: Fluent Button quando já adotado e disponível; caso contrário `<button>` semântico tokenizado.
- Gráfico: biblioteca definida pelo projeto em um componente custom, com tokens e alternativa textual; não classificar como Fluent oficial.
- Campo em Angular Forms: wrapper oficial + `ControlValueAccessor` tipado.

## Limites

- Não recrie com CSS um componente oficial que já atende ao caso.
- Não copie DOM, CSS ou APIs internas do Fluent React.
- Não altere bibliotecas escolhidas pelo usuário só para aumentar conformidade nominal.
- Componentes de terceiros podem coexistir quando fazem parte do requisito; alinhe superfície, tokens e acessibilidade sem afirmar que são Fluent oficiais.
