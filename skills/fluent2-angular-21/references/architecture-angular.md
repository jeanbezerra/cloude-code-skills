# Arquitetura Angular

## Inspeção inicial

Antes de editar, confirme:

- Angular e TypeScript efetivamente resolvidos no lockfile;
- standalone ou NgModule, SSR, prerender e hydration;
- mecanismo de tema e local onde os CSS custom properties são instalados;
- bibliotecas de componentes e ícones já usadas;
- comandos reais de lint, teste, build e E2E;
- versão e conteúdo de `node_modules/@fluentui/web-components/custom-elements.json`.

Se Angular for inferior a 21, não atualize silenciosamente. Separe a migração do framework da mudança visual ou registre o bloqueio.

## Registro dos Web Components

Prefira imports individuais com side effect e centralize-os em um arquivo carregado antes do bootstrap:

```ts
import '@fluentui/web-components/button.js';
import '@fluentui/web-components/text-input.js';
```

Valide cada caminho nos `exports` do `package.json` instalado. Não copie exemplos de outra major version.

## Wrappers Angular

Use wrapper standalone quando ele oferecer valor real: tipagem, adaptação de eventos, Angular Forms, SSR, acessibilidade ou API estável para a aplicação.

- `ChangeDetectionStrategy.OnPush`;
- `input()` e `output()` tipados;
- métodos com modificador de acesso explícito;
- `CUSTOM_ELEMENTS_SCHEMA` apenas no wrapper que contém as tags Fluent;
- sem `CUSTOM_ELEMENTS_SCHEMA` global para mascarar erros de template;
- sem manipular shadow DOM interno ou seletores privados.

Um wrapper simples não precisa de `ControlValueAccessor`. Implemente-o quando o controle for usado com `formControl`, `formControlName` ou `ngModel`.

## Ordem de inicialização

Property binding pode ocorrer antes de opções ou filhos projetados estarem prontos. Em componentes compostos:

1. registre todos os elementos exigidos pelo contrato do componente;
2. projete a estrutura indicada pelo Custom Elements Manifest e pelo código da versão instalada;
3. sincronize o valor depois da definição/conexão quando o valor inicial não aparecer;
4. teste valor inicial, mudança pelo usuário e atualização externa.

Use `customElements.whenDefined`, `afterNextRender`, `viewChild` ou uma fila curta apenas quando necessário. Prefira primeiro markup oficial correto.

## SSR e hydration

- Não acesse `window`, `document`, `customElements`, `matchMedia` ou storage durante SSR sem guarda de plataforma.
- Garanta registro determinístico no cliente antes da interação/hydration.
- Não assuma que todo Web Component oferece declarative shadow DOM na versão instalada.
- Execute ao menos o build SSR/prerender quando o projeto o utiliza.

## Dependências

Não force instalação ou upgrade se a tarefa puder usar a arquitetura existente. Se um pacote for necessário, registre versão no lockfile e confirme compatibilidade com Angular, TypeScript e o ambiente restrito do projeto.
