# F-001 — Inscrição de alunos — plano de execução

## Tarefas

| id | título | arquivos | deps | ACs |
|----|--------|----------|------|-----|
| T-001 | contrato de inscrição | `src/enroll/contract.ts`, `src/enroll/contract.test.ts` | — | AC-001, AC-002 |

## Paralelismo
- Uma única tarefa: paralelismo não se aplica.

## Notas
- `specs plan-check F-001` deve retornar 0 (arquivos disjuntos, deps válidas,
  sem ciclo, todo AC com dono).