# Specs — spec-anchored para opencode

Um fluxo **spec-driven design** onde a spec e o código evoluem juntos porque um
**gate mecânico** força o alinhamento o tempo todo. O "pronto" é **veredito da
máquina** (exit code do test runner), não uma frase do agente.

> Spec Kit, Kiro, OpenSpec são *spec-first*: a spec gera o código, o código
> evolui, e a spec vira ficção bem formatada. Aqui é **spec-anchored**: spec e
> código se alinham por um gate mecânico — e "isso aqui ainda funciona como está
> escrito?" tem resposta de comando, não de reunião.

---

## Como usar — você fala, o agente prova

Você não aprende comando nenhum. Os comandos `specs …` internos são executados
pelo agente, que **cola a prova na conversa**. Você conversa:

> — "Desenvolva a feature de inscrição de alunos."
>
> — (o agente faz perguntas, escreve os testes, implementa, documenta, revisa)
>
> — "Aprovo, commit."  →  um único commit no final, após a sua aprovação.
>
> — "Audita o que foi feito contra a spec."

### O pipeline TDD (1 comando, 6 fases, 1 commit)

```
F0 spec      → entender + fazer perguntas + documentar (spec.md, criteria.reg, A-/Q- resolvidas)
F1 tests     → escrever TESTES ANTES do código (TDD estrito) + registrar prova por AC
F2 implement → codar até os testes passarem
F3 docs      → documentar o feito (docs/features/<fid>.md citando cada AC)
F4 review    → deep review (6 subagentes review-*) + CORRIGIR achados
F5 commit    → apresentar diff final → SUA aprovação → COMMIT ÚNICO + merge
```

Uma spec = uma worktree = um diff = **um commit final**. Nada é commitado antes
da sua aprovação explícita (o permission `ask` do opencode cobre o ato). Você
pode abrir várias specs ao mesmo tempo (cada uma na sua worktree), mas cada uma
segue este pipeline linear.

O que você recebe sempre em português simples:

- **Especificação legível** em `.spec/features/<feature>/` — histórias, critérios,
  suposições e perguntas **resolvidas** antes de avançar.
- **Perguntas do agente**: entende a spec e te pergunta o que precisa
  documentar — nada é assumido em silêncio.
- **TDD estrito**: os testes são escritos primeiro e são a spec executável;
  cada critério (AC) ↔ um teste que passa.
- **Deep review automático** (segurança, performance, corretude, qualidade, testes,
  compat) com auto-correção transparente dos achados.
- **A prova**: auditoria mecânica — cada critério tem um teste que passou.
  Veredito = exit code, não frase.
- **Commit gated**: o diff final é apresentado a você e **só com a sua aprovação**
  é feito o commit único + merge.

---

## O que o sistema garante

| Garantia | Como |
|----------|------|
| Rastreabilidade de ponta a ponta | cada história, critério e tarefa tem código; cada AC aponta o teste que o prova (`criteria.reg` + `trace.tsv`) |
| Identificador âncora | feature com `--id <identificador>` (ex.: ticket do board) evita colisão de numeração entre devs e ancora em sistemas externos |
| "Pronto" é veredito da máquina | `specs proof`/`specs gate` decidem; teste pulado não conta |
| Nenhum commit sem sua aprovação | pipeline F5: diff apresentado → `--approve` → commit único; permission `ask` cobre o ato |
| TDD estrito | testes escritos antes do código; gate `tests` exige mapeamento AC→test |
| Revisão verifica padrão de código | deep review (subagentes `review-*`); `changes-required` bloqueia o gate `review` |
| Auto-correção transparente | achados corrigidos na spec (máx. 3 iterações), sempre reportando o quê/porquê |
| Suposições/perguntas obrigatórias | A-/Q- **resolvidas** na F0; feature não fecha com abertas |
| Constituição do projeto | preset LGPD/educação com verificação executável, rastreada até arquivo:linha |
| Lições com lastro | lição só entra ancorada em falha real; opinião solta é recusada (`specs lesson`) |
| Escala por spec, não por tarefa | 1 worktree por spec; worktrees por tarefa = modo avançado opcional |

---

## Instalação

```bash
git clone <este repo> && cd spec
./install.sh        # CLI ~/.local/bin/specs + skill enter config opencode
# reinicie o opencode
```

O `install.sh` também grava as regras de `permission` no opencode.json global
(se não existirem): `*git*commit*`/`*git*merge*`/`*git*push*`/`*specs*integrate*`
→ `ask`. Isso vale para todos os projetos desta máquina.

Uso no opencode: `/specs`, `/specs-develop`, `/specs-spec`, `/specs-status`,
`/specs-review`, `/specs-audit`, `/specs-resolve`, `/specs-lesson`,
`/specs-constitution`. (Modo avançado: `/specs-plan`, `/specs-run`,
`/specs-redo`.)

O `install.sh` também instala o **sistema de revisão automática** que o pipeline
F4 usa: o orquestrador `/review` e os 6 subagentes `review-*`
(`security`, `performance`, `correctness`, `quality`, `tests`, `compat`).
Eles são versionados neste repo (`commands/review.md`, `agents/review-*.md`) e
instalados em `~/.config/opencode/{command,agent}/`.

## Começar um projeto

```bash
cd <seu projeto>
specs init                                   # cria .spec/ (constituição LGPD/educação)
specs new "nome da feature"                  # F-001-<slug> (auto)
specs new "nome da feature" --id FIX-123     # identificador próprio (ex.: ticket do board)
# ...o agente descreve a spec, o plano, executa — tudo via comandos /specs*
```

O identificador da feature é `F-###` (automático) ou um valor seu via `--id` —
use o número do ticket do seu board para ancorar a feature em sistemas externos
e evitar colisões de numeração entre devs. Referencie sempre o `--id` (ex.:
`specs gate FIX-123 review`).

## Estrutura gerada

```
.spec/
  constitution.md    # constituição + verificações executáveis
  lessons.md         # lições com lastro
  features/<id>-<slug>/      # id = F-### (auto) ou custom via --id (ex.: FIX-123)
    spec.md            # spec legível (histórias U-, critérios AC-, A-/Q-)
    criteria.reg       # máquina: AC-id → story → descrição → dono
    assumptions.reg    # máquina: A-/Q- → status
    trace.tsv          # máquina: AC-id → comando de teste → sha
    reviews.reg        # máquina: T-SPEC → status/auto/deep/fixes (pipeline)
    phase.tsv          # máquina: fase → status (spec|tests|implement|docs|review|commit)
  trees/      # worktrees (ignorado pelo git) — 1 por spec
  locks/      # travas (ignorado pelo git)
```

## Provando o pipeline sozinho

1. `specs init`
2. `specs spec-open "Inscrição de alunos"` → spec + worktree única + phase.tsv
3. F0 `specs gate F-001 spec` → preenche spec.md/criteria.reg/assumptions.reg (A-/Q- resolvidas)
4. F1 `specs gate F-001 tests` → escreva tests ANTES + `specs prove F-001 AC-001 "<cmd>" T-SPEC`
5. F2 `specs gate F-001 implement` → implementa até `proof` passar (TDD)
6. F3 `specs gate F-001 docs` → `docs/features/F-001-*.md` citando cada AC
7. F4 `specs gate F-001 review` → deep review (6 subagentes) + `specs review F-001 T-SPEC --deep=approved`
8. F5 `specs commit F-001` → revisa o diff → `specs review F-001 T-SPEC --approve` → `specs commit F-001 --approve` → COMMIT ÚNICO + merge

Veja `docs/example/F-001-inscricao-de-alunos/` para uma feature completa.

## Desenvolvimento

- `bin/specs` + `lib/specs.sh` (núcleo) + `lib/commands.sh` (subcomandos).
- `commands/specs-*.md` + `commands/review.md` (comandos opencode) e
  `agents/review-*.md` (6 subagentes do deep review) — instalados pelo `install.sh`.
- `make test` = lint + `tests/smoke.sh` + `tests/smoke-parallel.sh` (tudo num golpe).
- `tests/smoke.sh` cobre o pipeline (spec-open → gates TDD → review → commit único
  gated) + garantias (drift, strict-skip, review, gate com constituição).
- `tests/smoke-parallel.sh` prova o modo avançado: escrita concorrente atômica
  (R2), status TSV parseável (R3), deps/integração e conflito de merge (R1).
- `./install.sh` roda o lint antes de instalar.

## Notas

- **Zero dependências**: só bash + git (flock/mkdir), grep nos scans da constituição.
- Formato mecânico = **TSV estruturado**; a "tabela linda" é o agente que desenha
  a partir de `specs status` — a máquina fala TSV, o agente fala português.# spec
