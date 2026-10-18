---
description: Registra uma lição aprendida ancorada em falha real (sem âncora, a lição é recusada).
---

# Specs — Registra lição aprendida

Carregue a skill `specs` e registre a lição em `.spec/lessons.md`.

$ARGUMENTS

Passos:
1. Escreva o registro num arquivo temporário no formato do template:
   - cabeçalho `## L-### — <título>`,
   - linha `- Ancora: …` citando a fonte da falha real (ex.: critério `AC-XXX`
     da feature `F-###` falhou com `<comando>`: <resumo> — fail/erro),
   - `- Lição: …` com o aprendizado concreto.
2. Registre com `specs lesson add <arquivo.md>` — valida a âncora E anexa em
   `lessons.md` com id `L-####` numerado automaticamente:
   - exit 0 = anexada (mostre a prova: o id gerado);
   - exit 2 = recusada (sem âncora/lastro real) — NÃO registre; explique por quê.
3. Reporte em PT-BR se a lição entrou (com prova) ou foi recusada.