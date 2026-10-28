# Componentes e formulários

## Fonte da API

O `custom-elements.json` instalado é a referência operacional para tags, membros e eventos. Consulte também `package.json#exports` e os arquivos do módulo quando a composição não estiver clara.

Não assuma que um componente composto aceita filhos diretos. Por exemplo, versões atuais do Dropdown podem exigir Dropdown + Listbox + Option; registre e projete todos os elementos exigidos pela versão local.

## Wrapper tipado

Um wrapper deve:

- expor apenas a API usada pela aplicação;
- converter eventos do custom element em outputs tipados;
- manter valor inicial e atualizações externas sincronizados;
- preservar `disabled`, label, descrição, required e invalid;
- manter alvo interativo mínimo quando aplicável;
- usar método `public`/`private` explícito.

Teste pelo menos:

1. renderização do valor inicial;
2. alteração pelo teclado e mouse;
3. emissão do valor correto;
4. atualização programática posterior;
5. estado disabled;
6. SSR/build quando utilizado.

## Angular Forms

Implemente `ControlValueAccessor` quando houver integração com Angular Forms:

- `writeValue` pode receber `null`;
- implemente `registerOnChange` e `registerOnTouched` para armazenar os callbacks recebidos do Angular Forms;
- chame o callback de mudança quando o usuário editar o valor e o callback de toque no `blur` ou evento equivalente, conforme a API do controle;
- `setDisabledState` sincroniza host e controle;
- evite emitir mudança de usuário durante `writeValue`;
- reflita validação e `aria-describedby` sem duplicar mensagens.

Veja o [contrato oficial de ControlValueAccessor](https://angular.dev/api/forms/ControlValueAccessor) para o registro e a chamada desses callbacks.

Para filtro local simples controlado por signal, `input()`/`output()` tipados normalmente bastam.

## Dialogs e overlays

Preserve foco inicial, trap de foco quando necessário, fechamento por Escape, retorno de foco, rotulagem e camada. Use portal/overlay já adotado pelo projeto; não crie infraestrutura global sem necessidade.
