# Iconografia

Use SVGs de `@fluentui/svg-icons` quando o projeto pede Fluent System Icons. Os arquivos seguem, em geral, o padrão `[nome]_[tamanho]_[estilo].svg`; confirme a versão instalada.

## Regras

- `regular` por padrão;
- `filled` para estado selecionado ou ênfase intencional;
- preserve o `viewBox` e o tamanho intrínseco do asset;
- SVG monocromático herda `currentColor`;
- ícone decorativo usa `aria-hidden="true"` e `focusable="false"`;
- botão icon-only tem nome acessível no botão;
- valide `directionType`/metadata antes de espelhar em RTL;
- não substitua por emoji, icon font, Material Icons, Lucide, Heroicons ou Font Awesome dentro do sistema Fluent sem requisito explícito.

Prefira import de SVG suportado pelo bundler ou um registry tipado pequeno. Se copiar `path` para um registry local, mantenha `viewBox`, registre a origem/pacote e não altere a geometria.

Não confunda tamanho do glifo com área clicável. Um ícone de 20 px pode viver em um botão de 44 × 44 px.
