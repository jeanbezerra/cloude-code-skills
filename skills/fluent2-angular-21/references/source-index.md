# Fontes oficiais

Consolidado em 22 de agosto de 2026. Para APIs instáveis, confirme novamente antes de atualizar dependências.

- Fluent UI Web Components — pacote, imports individuais, tema e CEM: https://github.com/microsoft/fluentui/tree/master/packages/web-components
- Fluent UI monorepo — posição dos Web Components como implementação framework-agnostic: https://github.com/microsoft/fluentui
- Fluent System Icons — pacote SVG e convenção de nomes: https://github.com/microsoft/fluentui-system-icons/tree/main/packages/svg-icons
- Fluent 2 Design System: https://fluent2.microsoft.design/
- WCAG 2.2: https://www.w3.org/TR/WCAG22/
- Angular — custom elements schema: https://angular.dev/api/core/CUSTOM_ELEMENTS_SCHEMA
- Angular — interoperabilidade com custom elements: https://angular.dev/guide/elements

Para o projeto em edição, a ordem de autoridade operacional é:

1. requisito explícito do usuário;
2. versão instalada e lockfile;
3. `custom-elements.json`, `package.json#exports` e tipos instalados;
4. documentação oficial correspondente àquela major version;
5. orientação geral desta skill.

Não use documentação de Fluent React como contrato de markup ou API para Web Components.
