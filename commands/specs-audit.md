---
description: Audita o que foi feito contra a spec — cada critério com teste que passou, veredito mecânico (exit code) e a prova colada.
---

# Specs — Audita contra a spec

Carregue a skill `specs` e execute a **Fase 5 (Auditoria)**.

$ARGUMENTS

Passos:
1. Rode `specs proof [--strict] [<f>]` e cole a saída completa (a prova) na conversa.
   - veredito: exit 0 = PASS, exit 1 = FAIL.
   - use `--strict` para garantir que teste pulado (skip) não valha como prova.
2. Rode `specs reconcile [<f>]` — acusa drift entre spec.md e criteria.reg.
3. Para fechamento completo, rode `specs gate <f>` — exige plano são, sem drift,
   tudo integrado, sem worktree órfão, todos os critérios provados, constituição
   respeitada e sem A-/Q- abertas.
4. Apresente o resultado em PT-BR:
   - quais critérios provados e por qual comando (teste),
   - qual critério NÃO tem prova registrada (se houver),
   - drift ou violação de constituição (se houver),
   - o veredito como `#verdict … PASS|FAIL` por extenso.

Você não declara vitória: **quem decide é o exit code.**