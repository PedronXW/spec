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

> — "Especifica a feature de inscrição de alunos."
>
> — "Boa. Divide em tarefas e gera o plano de execução."
>
> — "Pode rodar em paralelo. Me atualiza a cada minuto."
>
> — "A faixa 2 falhou — reexecuta só ela."
>
> — "Audita o que foi feito contra a spec e me mostra a prova."

O que você recebe sempre em português simples:

- **Especificação legível** em `.spec/features/<feature>/` — histórias de
  usuário e critérios de aceite escritos para gente (o detalhe técnico vai entre
  parênteses), mais suposições e perguntas em aberto que o agente é obrigado a
  confessar.
- **Plano com paralelismo opcional** — tarefas de arquivos disjuntos PODEM rodar
  em paralelo, cada uma em janela limpa (git worktree + branch próprios), 1
  tarefa = 1 commit rastreável. **Quem decide é você**: o agente recomenda e
  pergunta quais paralelizar — todas, algumas (resto em sequência na árvore
  principal) ou nenhuma.
- **Você sempre sabe o que rola** — antes de executar o agente avisa que as
  alterações vão rodar em background; a cada ~1 min ele cola a **tabela de
  andamento** (qual roda, qual não, o que concluiu/falhou) e um parágrafo-resumo
  em PT-BR; ao final, resumo completo.
- **Reexecução de faixa** — "reexecuta só a faixa 2": só a faixa 2, do zero, numa
  janela limpa, sem tocar no que já passou.
- **A prova** — auditoria mecânica: cada critério de aceite tem um teste que
  passou, ou a feature não está pronta. Verdict = exit code, não frase.
- **Revisão em 3 camadas** — 1) nenhum commit/merge/push roda sem sua aprovação
  no opencode (permission `ask`); 2) `specs auto-review` dá o veredito mecânico
  da janela (6 checks, exit code); 3) deep review com os subagentes
  `review-*` (segurança, performance, corretude, qualidade, testes, compat)
  verifica padrão de código — não só "funciona". Auto-issues e
  `changes-required` são **auto-corrigidos** na janela (máx. 3 iterações, com
  transparência); se não convergir, para e você decide.

---

## O que o sistema garante

| Garantia | Como |
|----------|------|
| Rastreabilidade de ponta a ponta | cada história, critério e tarefa tem código; cada AC aponta o teste que o prova (`criteria.reg` + `trace.tsv`) |
| "Pronto" é veredito da máquina | `specs proof`/`specs gate` decidem; teste pulado não conta |
| Nenhum commit sem revisão | permission `ask` no opencode (`*git*commit*`, `*git*merge*`, `*git*push*`, `*specs*integrate*`) — todo commit/merge exige seu allow |
| Revisão verifica padrão de código | auto-review mecânico + deep review (subagentes `review-*`); `changes-required` bloqueia integrate/gate |
| Auto-correção transparente | falhas mecânicas/deep são corrigidas na janela (máx. 3 iterações), sempre reportando o quê/porquê; sem convergir, para |
| Suposições e perguntas obrigatórias | registradas com status; feature não fecha com A-/Q- aberto (`assumptions.reg`) |
| Constituição do projeto | preset LGPD/educação com verificação executável, rastreada até arquivo:linha |
| Lições com lastro | lição só entra ancorada em falha real; opinião solta é recusada (`specs lesson`) |
| Execução paralela planejada | tarefas de arquivos disjuntos em worktrees/branches próprios, integração com dry-merge |
| Escrita concorrente segura | travas (`flock`/mkdir atômico) em `prove`/`state`/`integrate`/`resolve`/`review` |

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

Uso no opencode: `/specs`, `/specs-spec`, `/specs-plan`, `/specs-run`,
`/specs-review`, `/specs-redo`, `/specs-status`, `/specs-audit`,
`/specs-resolve`, `/specs-lesson`, `/specs-constitution`.

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
    plan.md            # plano: tarefas, deps, paralelismo
    criteria.reg       # máquina: AC-id → story → descrição → dono T-id
    assumptions.reg    # máquina: A-/Q- → status
    trace.tsv          # máquina: AC-id → comando de teste → sha
    state.tsv          # máquina: T-id → status → branch → sha
    tasks/T-XXX.md     # janela de execução por tarefa
  trees/      # worktrees (ignorado pelo git)
  locks/      # travas (ignorado pelo git)
```

## Provando a auditoria sozinho

1. `specs init`
2. `specs new "Inscrição de alunos"`
3. edite `criteria.reg`, `tasks/T-001.md`, `assumptions.reg` (spec.md consistente!)
4. `specs plan-check .` → deve passar
5. `specs reconcile F-001` → sem drift spec.md ↔ criteria.reg
6. `specs prove [--strict] F-001 AC-001 "test -f seu_arquivo" T-001`
7. `specs proof F-001` → exit 0 = PASS
8. `specs auto-review F-001 T-001` → exit 0 = auto-ok (6 checks mecânicos)
9. `specs review F-001 T-001` → mostra o diff; `specs review F-001 T-001 --approve`
10. `specs integrate F-001 T-001` → exit 0 (exige approved + sha + auto-ok)
11. `specs gate F-001` → exit 0 = feature fecha
    (plano são + sem drift + integradas + revisão aprovada + sem worktree órfão +
     prova ok + constituição ok + sem A-/Q- abertas)

Veja `docs/example/F-001-inscricao-de-alunos/` para uma feature completa.

## Desenvolvimento

- `bin/specs` + `lib/specs.sh` (núcleo) + `lib/commands.sh` (subcomandos).
- `make test` = lint + `tests/smoke.sh` + `tests/smoke-parallel.sh` (tudo num golpe).
- `tests/smoke.sh` cobre o ciclo inteiro + novas garantias (drift, strict-skip,
  worktree órfão, gate com constituição, gate de revisão: integrate sem aprovação
  falha, sha alterado pós-aprovação falha, auto-issues bloqueia).
- `tests/smoke-parallel.sh` prova os refinamentos: escrita concorrente atômica
  (R2), status TSV parseável (R3), deps/integração e conflito de merge (R1).
- `./install.sh` roda o lint antes de instalar.

## Notas

- **Zero dependências**: só bash + git (flock/mkdir), grep nos scans da constituição.
- Formato mecânico = **TSV estruturado**; a "tabela linda" é o agente que desenha
  a partir de `specs status` — a máquina fala TSV, o agente fala português.# spec
