---
description: Executa o pipeline TDD completo de uma spec — perguntas → testes → implementar → docs → deep review → aprovação sua → commit único.
---

# Specs — Desenvolve uma spec (pipeline TDD)

Carregue a skill `specs` e execute o **pipeline sequencial** da spec.

$ARGUMENTS

**Identificador (`<f>`):** se os argumentos (ou o pedido) tiverem um id (ex.:
`--id JIRA-452`), passe-o em `specs spec-open "<nome>" --id <id>` na abertura e
use esse mesmo id em TODOS os comandos do pipeline (`specs gate <id> …`,
`specs prove <id> …`). Sem id, o sistema gera `F-###` automático.

## Seu papel
Executar fase a fase, **colando a prova (exit code) de cada gate** na conversa.
Nada é commitado antes da aprovação final do usuário.

## Fases (ordem forçada — `specs gate <f>` não deixa pular)

1. **Abrir**: `specs spec-open "<nome>" [--id <identificador>]` (se ainda não
   aberta) → worktree ÚNICA da spec. Se o usuário tiver um id do board/sistema
   externo, use `--id <ticket>` — é a âncora da feature em sistemas externos.
2. **F0 spec** (`specs gate <f> spec`):
   - Entenda a spec, **faça perguntas** ao usuário e documente: `spec.md` (histórias U-),
     `criteria.reg` (ACs), `assumptions.reg` (A-/Q- **resolvidas** — nenhuma em aberto).
   - Gate só passa com spec.md preenchido + ACs registrados + zero A-/Q- abertas.
3. **F1 tests** (`specs gate <f> tests`):
   - **Escreva os TESTES ANTES do código** na worktree da spec (`specs status <f>` mostra a árvore).
   - Registre a prova: `specs prove <f> <AC-id> "<comando>" T-SPEC` (rojo legítimo — pode falhar).
   - Gate: todo AC tem teste registrado.
4. **F2 implement** (`specs gate <f> implement`):
   - Implemente até os testes passarem (o gate roda `specs proof` na árvore ativa).
   - Nada de commit — trabalhe no working tree da worktree.
5. **F3 docs** (`specs gate <f> docs`):
   - Documente o que foi feito em `docs/features/<fid>.md`, citando cada AC.
6. **F4 review** (`specs gate <f> review`):
   - Rode o **deep review** (6 subagentes `review-security`, `review-performance`,
     `review-correctness`, `review-quality`, `review-tests`, `review-compat`) sobre o
     diff `git diff <base>...spec/<fid>`.
   - **Corrija os achados** (segurança, qualidade, corretude, …) com transparência
     (reporte o que e por quê). Grave: `specs review <f> T-SPEC --deep=<verdict>`.
   - O gate também roda a constituição na árvore ativa.
7. **F5 commit**:
   - `specs commit <f>` → apresenta o diff FINAL e o estado.
   - **PARE e peça a aprovação do usuário.** Somente com "aprovado":
     `specs review <f> T-SPEC --approve` e depois `specs commit <f> --approve`
     → commit ÚNICO + merge + worktree limpa.

## Garantias
- **Nenhum commit/merge antes de F5** (permission `ask` no opencode cobre o ato).
- **Ordem forçada**: `specs gate` recusa pular fase (anterior não-done).
- **TDD estrito**: testes vêm antes do código.
- A cada fase, cole a saída do gate (a prova). Você não declara vitória: o exit code decide.