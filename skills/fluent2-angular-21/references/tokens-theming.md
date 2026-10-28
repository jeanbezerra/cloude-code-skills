# Tokens e temas

## Tema

Instale o tema solicitado usando `setTheme` e um tema de `@fluentui/tokens`, conforme os exports da versão instalada.

- Se o usuário pediu light-only, implemente e teste apenas light.
- Se pediu dark-only, respeite dark-only.
- Se pediu alternância ou modo system, implemente os modos, persistência e `prefers-color-scheme` solicitados.
- Se não especificou, preserve o comportamento existente; não crie um seletor de tema por padrão.

## Tokens

Use alias tokens semânticos para superfície, texto, borda, foco, tipografia, espaçamento, raio, sombra e motion, por exemplo:

```css
.card {
  color: var(--colorNeutralForeground1);
  background: var(--colorNeutralBackground1);
  border: var(--strokeWidthThin) solid var(--colorNeutralStroke2);
  border-radius: var(--borderRadiusMedium);
  padding: var(--spacingVerticalM) var(--spacingHorizontalL);
}
```

Não imponha substituição mecânica quando não existir token com a mesma semântica. Valores exatos podem ser necessários para:

- contrato de uma API gráfica ou canvas;
- tamanho mínimo acessível;
- breakpoint derivado da quebra real do conteúdo;
- dimensão técnica sem equivalente Fluent.

Documente tokens de produto centralmente. Cores de métricas, status HTTP ou séries de gráficos são tokens de domínio; derive de alias Fluent quando isso preservar contraste e distinção.

## Contraste e estados

Valide combinações reais de foreground/background em estados default, hover, active, selected, disabled e focus. Não comunique estado apenas por cor. Em forced colors, preserve bordas e foco com cores do sistema.

Evite seletores internos do shadow DOM. Use atributos, slots, parts e tokens documentados pela versão instalada.
