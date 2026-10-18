---
description: Divide a feature em tarefas, registra o plano de execução e audita o plano mecanicamente.
---

# Specs — Gera o plano de execução

Carregue a skill `specs` e execute a **Fase 2 (Plano)**.

$ARGUMENTS

Passos:
1. A feature já deve ter `spec.md` e `criteria.reg` (use `/specs-spec` antes, se
   necessário — diga isso ao usuário).
2. Quebre a feature em tarefas `T-###` e escreva `tasks/T-###.md` para cada:
   - `- <arquivos>` que ela toca (para DETERMINAR disjunção),
   - `Deps:` (dependências entre tarefas),
   - `ACs:` (critérios que a tarefa prova),
   - `Run:` (comando de verificação da janela).
3. Ligue cada AC ao seu dono em `criteria.reg`.
4. Rode `specs plan-check <f>` — a máquina valida (arquivos disjuntos + deps
   + sem ciclo). Não continue com saída != 0; corrija o plano.
5. Escreva `plan.md` com a tabela de tarefas e a recomendação de paralelismo.
6. **PERGUNTE ao usuário** quais tarefas levar em paralelo (todas / algumas /
   nenhuma) — as disjuntas PODEM paralelizar, mas quem decide é ele.