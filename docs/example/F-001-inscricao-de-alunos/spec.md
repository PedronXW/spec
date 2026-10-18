# F-001 — Inscrição de alunos

## Histórias de usuário
- **U-001 — Como** secretária escolar, **quero** cadastrar uma inscrição de aluno
  com CPF e matrícula, **para** registrar a entrada da turma. (contrato em
  `src/enroll/contract.ts`)

## Critérios de aceite
> Critérios vivem mecanicamente em `criteria.reg` (AC-id → story → semântica
> técnica → dono T-id). Aqui a spec os refere por legibilidade.

- **AC-001** — Cadastro aceita CPF válido (parse não lança exceção) — prova em `trace.tsv`.
- **AC-002** — Cadastro recusa CPF inválido (parse lança erro de validação) — prova em `trace.tsv`.

## Suposições (open/confirmed/rejected — em `assumptions.reg`)
- **A-001** — A secretária opera em ambiente autenticado (não expomos autenticação nesta feature). — **confirmada**

## Perguntas em aberto
- (nenhuma)

## Registro mecânico
- `criteria.reg`: AC-001, AC-002 atribuídos à T-001.
- `trace.tsv`: AC-001 → `npx vitest run src/enroll/contract.test.ts` (PASS).
- `state.tsv`: T-001 → integrated.