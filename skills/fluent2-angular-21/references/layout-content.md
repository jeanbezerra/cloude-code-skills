# Layout e conteúdo

## Escopo de viewport

Respeite o produto:

- Em produto responsivo, faça reflow nos breakpoints determinados pelo conteúdo e teste os viewports suportados.
- Em produto desktop-only explicitamente definido, preserve a largura mínima e teste o menor desktop suportado, zoom, rolagem e teclado. Não adicione navegação mobile ou reflow para 320 px sem solicitação.
- Não interprete “desktop” como permissão para cortar conteúdo: tabelas podem rolar no eixo inline e controles essenciais continuam acessíveis.

Use Grid/Flex, propriedades lógicas e a escala Fluent de espaçamento. Grid de 12 colunas é uma ferramenta, não uma obrigação.

## Conteúdo

- sentence case, voz ativa e termos consistentes;
- labels e botões sem ponto final;
- links descrevem o destino;
- mensagens indicam problema e próxima ação;
- não dependa de “acima”, “abaixo”, “à esquerda” ou “à direita”.

## Estados

- abaixo de 1 s: normalmente não mostrar indicador;
- entre 1 e 3 s: spinner contextual quando necessário;
- acima de 3 s ou progresso mensurável: status persistente, progress ou skeleton;
- preserve conteúdo útil durante atualização;
- implemente empty/error/loading somente quando o fluxo pode alcançar esses estados.

Onboarding deve ser opcional, contextual e descartável. Handoffs preservam contexto e deixam claro o próximo passo.

## IA

Quando a interface usar IA, identifique essa participação, explique dados/fontes/limitações, permita correção e evite autoridade visual excessiva. Não acrescente uma experiência de IA a uma tarefa comum de UI.
