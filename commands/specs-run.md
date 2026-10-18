---
description: Executa o plano de execução — janelas limpas em paralelo (se autorizado), tabela de andamento a cada 1 min e resumo final em PT-BR.
---

# Specs — Executa o plano

Carregue a skill `specs` e execute a **Fase 3 (Execução)** e a **Fase 4 (Integração)**.

$ARGUMENTS

Passos:
1. **Confirme o modo de execução com o usuário** se ainda não decidido:
   paralelo (quais faixas), ou tudo na ordem na árvore principal.
2. **Avise antes**: as alterações vão rodar em background; a cada minuto vai
   haver tabela de andamento.
3. Para cada faixa que roda em janela própria: `specs track <f> <T-id>`.
   Dentro de cada janela: tocar só nos arquivos da tarefa, rodar o `Run:`,
   fazer EXATAMENTE 1 commit `T-###: <título>`; depois `specs state <f> <T-id> done|failed`.
4. **A cada ~1 min**: `specs status <f>` → tabela de andamento (qual roda, qual
   parou, o que concluiu/falhou) + resumo de andamento em parágrafo PT-BR.
5. Ao concluir: `specs integrate <f> <T-id>` na ordem das dependências.
6. Resumo completo final da execução em PT-BR.

Se uma faixa falhou e o usuário pedir reexecução, pare e use `/specs-redo <T-id>`.