---
description: Fluxo completo spec-anchored — especificando, desenvolvendo TDD, revisando e commitando com prova mecânica.
---

# Specs — spec-anchored

Carregue a skill `specs` e execute o fluxo. Seu papel: converter o pedido do
usuário em prova mecânica, **nunca em opinião**.

$ARGUMENTS

Fase o pedido:
- "desenvolv/desarrolla/implementa X" → `/specs-develop` (pipeline TDD completo).
- "especifica X" → Fase 0 (Especificação): `specs spec-open` + spec.md/criteria.reg/
  assumptions.reg; **faça perguntas**; confesse suposições e resolva A-/Q-.
- "escribe testes para X" → Fase 1: testes antes do código + `specs prove` T-SPEC.
- "implementa/testes passam" → Fase 2: `specs gate <f> implement`.
- "revisa / deep review" → Fase 4: deep review (6 subagentes) + corrigir achados.
- "commita X" → Fase 5: `specs commit <f>`, **PARE e peça aprobación**, luego `--approve`.
- "audita" / "prova" → `specs proof [--strict]` e `specs audit` (modo avançado).
- "constitución" → `specs constitution scan`.
- "lição" → `specs lesson add <arquivo.md>`.

Cola sempre a saída dos comandos (a prova) na resposta. Nunca commites antes
de la aprobación explícita del usuario.