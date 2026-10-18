---
description: Roda as verificações executáveis da constituição do projeto e mostra arquivo:linha de cada violação.
---

# Specs — Verifica a constituição

Carregue a skill `specs` e execute `specs constitution scan`.

$ARGUMENTS

1. Rode `specs constitution scan` e cole a saída integral.
   - exit 0 = constituição respeitada;
   - exit 1 = violação — mostre cada `arquivo:linha` e a regra violada.
2. Se houver violação e o usuário pedir correção, corrija e rode de novo até
   exit 0. Nunca "justifique" violação executável.
3. Grave nos arquivos a regra como ela foi fixada, se a regra exigir ajuste
   de padrão (ex.: diretórios do projeto) — não para amolecer a regra.