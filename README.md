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

> — "Desarrolla la feature de inscrição de alumnos."
>
> — (el agente hace preguntas, escribe los tests, implementa, documenta, revisa)
>
> — "Aprobo, commit."  →  un único commit al final, tras tu aprobación.
>
> — "Audita lo que se hizo contra la spec."

### El pipeline TDD (1 comando, 6 fases, 1 commit)

```
F0 spec      → entender + hacer preguntas + documentar (spec.md, criteria.reg, A-/Q- resueltas)
F1 tests     → escribir TESTES ANTES del código (TDD estricto) + registrar prueba por AC
F2 implement → codar hasta que los tests pasen
F3 docs      → documentar lo hecho (docs/features/<fid>.md citando cada AC)
F4 review    → deep review (6 subagentes review-*) + CORREGIR achados
F5 commit    → presentar diff final → TU aprobación → COMMIT ÚNICO + merge
```

Una spec = una worktree = un diff = **un commit final**. Nada se commitea
antes de tu aprobación explícita (el permission `ask` del opencode cubre el acto).
Puedes abrir varias specs a la vez (cada una en su worktree), pero cada una sigue
este pipeline lineal.

Lo que recibes siempre en portugués simple:

- **Especificación legible** en `.spec/features/<feature>/` — historias, criterios,
  suposiciones y preguntas **resueltas** antes de avanzar.
- **Preguntas del agente**: entiende la spec y te pregunta lo que necesita
  documentar — nada se asume en silencio.
- **TDD estricto**: los tests se escriben primero y son la spec ejecutable;
  cada criterio (AC) ↔ un test que pasa.
- **Deep review automático** (seguridad, performance, corretud, calidad, tests,
  compat) con auto-corrección transparente de los achados.
- **La prueba**: auditoría mecánica — cada criterio tiene un test que pasó.
  Veredicto = exit code, no frase.
- **Commit gated**: el diff final se te presenta y **solo con tu aprobación**
  se hace el commit único + merge.

---

## O que o sistema garante

| Garantia | Como |
|----------|------|
| Rastreabilidade de ponta a ponta | cada história, critério e tarefa tem código; cada AC apunta o teste que o prova (`criteria.reg` + `trace.tsv`) |
| "Pronto" é veredito da máquina | `specs proof`/`specs gate` decidem; teste pulado não conta |
| Nenhún commit sem sua aprobación | pipeline F5: diff presentado → `--approve` → commit único; permission `ask` cobre o ato |
| TDD estrito | testes escritos antes do código; gate `tests` exige mapeo AC→test |
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

## Começar um projeto

```bash
cd <seu projeto>
specs init                                   # cria .spec/ (constituição LGPD/educação)
specs new "nome da feature"                  # F-001-<slug>
# ...o agente descreve a spec, o plano, executa — tudo via comandos /specs*
```

## Estrutura gerada

```
.spec/
  constitution.md    # constituição + verificações executáveis
  lessons.md         # lições com lastro
  features/F-XXX-<slug>/
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
