---
description: Confirma ou rejeita uma suposição (A-) ou responde uma pergunta em aberto (Q-).
---

# Specs — Resolve suposição/pergunta

Carregue a skill `specs` e use o comando `specs resolve`.

$ARGUMENTS

Esperado do usuário algo como "confirma A-001" ou "rejeita a suposição 2" ou
"A resposta pra Q-001 é …". Identifique a feature (`f`), o id (`A-###`/`Q-###`)
e o status: `confirmed` (confirmada) | `rejected` (rejeitada, vira decisão) | `answered` (pergunta respondida).

Passos:
1. Atualize `assumptions.reg`: rode `specs resolve <f> <id> <status>`; se a
   pergunta Q trouxe resposta, é `answered`.
2. Se rejeitada, corrija a spec (spec.md + criteria.reg) documentando a decisão.
3. Cole a saída; informe se ainda há A-/Q- em aberto.