---
name: specs
description: Fluxo spec-anchored (spec-driven design com prova mecânica). Use quando o projeto tem um diretório .spec/ OU quando o usuário chama comandos /specs* (develop, spec, plan, run, redo, status, audit, review, resolve, lesson, constitution) ou pede para especificar uma feature, desenvolver com TDD, fazer perguntas sobre a spec, auditar critérios, registrar lição ou checar a constituição do projeto. Centraliza o pipeline especificar → testar → implementar → documentar → revisar → aprovar → commitar, com veredito mecânico (exit code), não textual.
---

# Specs — Spec-Anchored Workflow

Você é o executor do fluxo **spec-anchored**: a spec e o código evoluem juntos,
porque um **gate mecânico** força o alinhamento o tempo todo. O "pronto" é
veredito da máquina — o test runner —, **nunca uma frase sua**.

Tudo que você diz ao usuário é em **português simples**. Os comandos internos
`specs …` nada mais são que ferramentas; você executa e **cola a prova** na
conversa.

---

## Fluxo principal: pipeline TDD sequencial (`/specs-develop`)

> **Uma spec = uma worktree = um diff = um commit final.**
> O caminho feliz é **sequencial**, uma coisa de cada vez, com gates mecânicos.
> Você pode abrir **várias specs ao mesmo tempo** (cada uma na sua worktree
> única) — mas cada uma segue este pipeline linear, sem abrir worktrees por tarefa.

```
F0 spec      → entender + FAZER PERGUNTAS + documentar (spec.md, criteria.reg, A-/Q- resolvidas)
   gate:     specs gate <f> spec → exit 0
F1 tests     → ESCREVER TESTES ANTES do código (TDD) + specs prove <AC> <cmd> T-SPEC
   gate:     specs gate <f> tests → exit 0
F2 implement → codar na worktree da spec até os testes passarem
   gate:     specs gate <f> implement → exit 0 (roda specs proof)
F3 docs      → documentar o feito em docs/features/<fid>.md citando cada AC
   gate:     specs gate <f> docs → exit 0
F4 review    → DEEP REVIEW (6 subagentes review-*) sobre o diff + CORRIGIR achados
   gate:     specs gate <f> review → exit 0 (deep aprobado + constituição ok)
F5 commit    → specs commit <f> (diff final) → PEDIR APROVAÇÃO → --approve → COMMIT ÚNICO + merge
```

### Regras do pipeline (imutáveis)
- **Nenhum commit/merge antes de F5.** O agente trabalha no working tree da
  worktree da spec; o permission `ask` do opencode cobre o ato de commitar.
- **Ordem forçada**: `specs gate <f>` recusa avançar se a fase anterior não
  está `done`.
- **TDD estrito**: os testes são escritos ANTES do código e são a spec
  executável (cada AC ↔ um teste que passa).
- **Revisão automática de qualidade/segurança**: o deep review usa os 6
  subagentes `review-*`; `changes-required` bloqueia. Auto-correção com
  transparência (reporte o que e por quê), máx. 3 iterações.
- **Aprovação do usuário é obrigatória** antes do commit final.

### Fases em detalhe (quando o usuário não usa `/specs-develop`)

**F0 — Especificação (`/specs-spec`)** — `specs new` / `specs spec-open`:
- Entenda a spec, faça perguntas, documente: histórias `U-###`, critérios
  `AC-###` em `criteria.reg`, suposições `A-###` e perguntas `Q-###` em
  `assumptions.reg` — **tudo resolvido antes de seguir** (nenhuma em aberto).
- Detalhe técnico vai entre parênteses; histórias legíveis para gente.

**F1 — Testes** — escreva os testes ANTES do código, na worktree da spec
(`specs status <f>` mostra a árvore ativa). Registre cada AC com
`specs prove <f> <AC-id> "<comando>" T-SPEC`.

**F2 — Implementação** — desenvolva até `specs gate <f> implement` passar
(roda `specs proof` na árvore ativa). Teste pulado não conta (use
`specs prove --strict` se o runner pode pular).

**F3 — Documentação** — `docs/features/<fid>.md` citando cada AC implementado.

**F4 — Revisão automática** — deep review (6 subagentes `review-*`) sobre o
diff `git diff <base>...spec/<fid>`; consolide relatório estilo PR
(`APPROVED | CHANGES REQUIRED | APPROVED WITH SUGGESTIONS` + severidade
`file:line`); **corrija** os achados; grave `specs review <f> T-SPEC --deep=<verdict>`.
Constituição também é verificada.

**F5 — Commit final** — `specs commit <f>` apresenta o diff; **PARE e peça a
aprovação**; com "aprovado": `specs review <f> T-SPEC --approve` e
`specs commit <f> --approve` → commit único + merge + worktree limpa.

### Reexecução / ajuste
- Spec já aberta: continue de onde parou com `specs gate <f>` (mostra a fase
  pendente) e os comandos da fase.
- "Reexecuta só a faixa N" e comandos por-tarefa (`track`, `integrate`,
  `auto-review`) são do **modo avançado** abaixo.

---

## Modo avançado (features muito grandes / refactors)

Para features enormes que justificam dividir em tarefas paralelas: o fluxo
antigo continua disponível — `specs track <f> <T-id> [--clean]` (janela por
tarefa), `specs state`, `specs integrate`, `specs auto-review`, `specs review
<f> <T-id> --approve`. Cada tarefa = 1 worktree + 1 commit, integrada na ordem.
**Não é o caminho padrão** — use só quando o pipeline único não escala.

---

## Constituição (`/specs-constitution`)
- A constituição vive em `.spec/constitution.md` (preset LGPD/educação no init).
- `specs constitution scan` → exit 0 = respeito; exit 1 = violação (file:line)
  ou não-verificável. Feature não fecha com violação. O gate de review também
  roda a constituição na árvore ativa.

## Lições (`/specs-lesson`)
- `specs lesson add <arquivo.md>` valida a âncora E anexa com `L-####`.
  Sem âncora em falha real → exit 2 (nada é anexado).

## Regras nucleares (imutáveis)

1. **Pronto = exit code**, não frase. `proof`/`gate` decidem; você reporta.
2. **Teste pulado não é prova.** Com `--strict`, skip vira falha mesmo com exit 0.
3. **Suposições/perguntas abertas bloqueiam o fechamento** (F0 exige resolvidas).
4. **Nenhum commit/merge sem a aprovação do usuário** (permission `ask` + F5).
5. **Revisar é verificar funcionamento E padrão de código** (deep review
   `review-*`); `changes-required` bloqueia; auto-correção transparente.
6. **TDD estrito**: testes antes do código; cada AC ↔ um teste que passa.
7. **Constituição violada bloqueia.**
8. **Spec e mecânica não divergem** (`reconcile`).
9. Responda e produza aparato sempre em **português simples** (salvo IDs/comandos).

## Comandos internos (referência rápida)

| comando | papel |
|--------|-------|
| `specs init [--no-constitution]` | cria projeto .spec/ |
| `specs spec-open <nome> [slug]` | abre spec: feature + worktree ÚNICA + phase.tsv |
| `specs phase <f> [fase status]` | mostra/define estado das fases |
| `specs gate <f> [fase]` | gate da fase pendente (ordem forçada, exit code) |
| `specs commit <f> [--approve]` | diff final; `--approve` faz COMMIT ÚNICO + merge |
| `specs review <f> T-SPEC --deep=<v>` | grava veredito do deep review da spec |
| `specs review <f> T-SPEC --approve` | grava aprovação do usuário da spec |
| `specs prove [--strict] <f> <AC> <cmd> T-SPEC` | registra prova de critério (lock) |
| `specs proof [--strict] [<f>]` | veredito executável (exit code) |
| `specs status [<f>]` | tabela mecânica TSV (árvore ativa, fases) |
| `specs resolve <f> <id> <status>` | fecha suposição/pergunta (lock) |
| `specs audit <f>` | auditoria final consolidada (modo avançado) |
| `specs reconcile [<f>]` | drift spec.md ↔ criteria.reg |
| `specs constitution [scan]` | verifica constituição |
| `specs lesson [add] <arquivo.md>` | valida/anexa lição (exit 2 sem âncora) |
| `specs new/plan-check/track/state/integrate/auto-review` | modo avançado (por tarefa) |
