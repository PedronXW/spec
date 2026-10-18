---
description: Reexecuta só uma faixa (T-id) do zero, numa janela limpa, sem tocar nas que passaram.
---

# Specs — Reexecuta a faixa <T-id>

Carregue a skill `specs` e execute a **Reexecução**.

$ARGUMENTS

A faixa a reexecutar é: T-id do argumento (ex.: "reexecuta a faixa 2"). Se o
argumento vier como número, monte o `T-0<id>` correspondente.

Passos:
1. Identifique a feature (`f`) e o `T-id`.
2. `specs track <f> <T-id> --clean` — ROMPE a janela antiga e abre do zero.
3. Rode a tarefa dentro da janela limpa (arquivos da tarefa, `Run:`, 1 único
   commit `T-###: <título>`).
4. `specs state <f> <T-id> done|failed`.
5. `specs integrate <f> <T-id>`.
6. Prove novamente os critérios afetados: `specs prove <f> <AC-id> "<cmd>" <T-id>`.
7. Reporte em PT-BR; cole a prova. **Não toque nas faixas que passaram.**