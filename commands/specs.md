---
description: Fluxo completo spec-anchored — especificando, planejando, executando, auditando com prova mecânica.
---

# Specs — spec-anchored

Carregue a skill `specs` e execute o fluxo. Seu papel: converter o pedido do
usuário em prova mecânica, **nunca em opinião**.

$ARGUMENTS

Fase o pedido:
- "especifica X" → Fase 1 (Especificação): `specs new <X>` + escrever spec.md,
  criteria.reg e assumptions.reg; confessar suposições/perguntas abertas.
- "plano" / "divide em tarefas" → Fase 2 (Plano): decompor em T-###, escrever
  tasks/T-###.md, rodar `specs plan-check`, e PERGUNTAR o paralelismo.
- "roda" / "executa" → Fase 3 (Execução): janelas limpas, status a cada 1 min,
  resumo PT-BR.
- "redobrar / reexecuta a faixa N" → `/specs-redo`.
- "audita" / "prova" → Fase 5 (Auditoria): `specs proof [--strict]` e `specs gate`,
  VEREDITO = exit code (inclui reconcile + constituição).
- "constituição" → `specs constitution scan`.
- "lição" → `specs lesson add <arquivo.md>` (valida + anexa com L-####).

Cola sempre a saída dos comandos (a prova) na resposta.