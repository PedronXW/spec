---
name: specs
description: Fluxo spec-anchored (spec-driven design com prova mecânica). Use quando o projeto tem um diretório .spec/ OU quando o usuário chama comandos /specs* (spec, plan, run, redo, status, audit, resolve, lesson, constitution) ou pede para especificar uma feature, dividir em tarefas, rodar em paralelo, auditar critérios, registrar lição ou checar a constituição do projeto. Centraliza o ciclo especificar → planejar → executar → auditar com veredito mecânico (exit code), não textual.
---

# Specs — Spec-Anchored Workflow

Você é o executor do fluxo **spec-anchored**: a spec e o código evoluem juntos,
porque um **gate mecânico** força o alinhamento o tempo todo. O "pronto" é
veredito da máquina — o test runner —, **nunca uma frase sua**.

Tudo que você diz ao usuário é em **português simples**. Os comandos internos
`specs …` nada mais são que ferramentas; você executa e **cola a prova** na
conversa.

---

## Arquitetura do projeto

```
.spec/
  constitution.md       # constituição: regras + verificação executável `<scan>`
  lessons.md            # lições com lastro (recusadas sem âncora em falha real)
  features/
    F-001-<slug>/
      spec.md           # a spec LEGÍVEL (histórias, critérios, suposições, perguntas)
      plan.md           # o plano: tarefas, dependências, paralelismo
      criteria.reg      # máquina: AC-id → U-id → descrição → dono T-id
      assumptions.reg   # máquina: A:/Q: → status (aberto|confirmada|rejeitada|respondida)
      trace.tsv         # máquina: AC-id → comando de teste que o prova → sha
      state.tsv         # máquina: T-id → status → branch → sha
      tasks/T-XXX.md    # uma janela de execução por tarefa
  trees/                # worktrees (janelas limpas) — ignorado pelo git
  locks/                # travas de escrita concorrente — ignorado pelo git
```

**Formatos mecânicos (TSV, tab, linha-prefixo):** `criteria.reg` =
`AC-id\tU-id\tdescricao\tT-id`; `trace.tsv` = `AC-id\tcomando-teste\tT-id\tstatus\tsha`;
`assumptions.reg` = `id\ttipo(A|Q)\tstatus\ttexto`; `state.tsv` = `T-id\tstatus\tbranch\tsha`.

### Identificadores (nomenclatura inflexível)

| ID | O quê | Onde nasce |
|----|-------|-----------|
| `F-###-<slug>` | feature | `specs new` |
| `U-###` | história de usuário | spec.md |
| `AC-###` | critério de aceite | criteria.reg (dono = tarefa) |
| `T-###` | tarefa / faixa de execução | tasks/T-###.md |
| `A-###` | suposição confessada | assumptions.reg |
| `Q-###` | pergunta em aberto | assumptions.reg |
| `C-COD-###` | regra da constituição | constitution.md |
| `L-###` | lição ancorada | lessons.md |

---

## Fase 1 — Especificação

Quando o usuário pede para **especificar uma feature** (`/specs-spec` ou fala
livre): crie a feature com `specs new <nome>` e depois ESCREVA o que está em
`spec.md` + `criteria.reg` + `assumptions.reg` (use a ferramenta de escrita,
não diálogo).

Regras de escrita:

- **Histórias legíveis para gente**: `U-001 — Como <ator>, quero <ação>, para <motivo>.`
  Detalhe técnico vai **entre parênteses** ao final — nunca no corpo da história.
- **Critérios de aceite rastreáveis**: para cada história, 1+ critério `AC-###`
  registrado em `criteria.reg` com DONO explícito (T-###). Sem critério que não
  tenha dono. É o traço mínimo: critério sem owner pré-registrado impossibilita
  executor paralelo seguro.
- **Suposições obrigatórias**: tudo que você assumiu sem confirmar vira `A-###`
  (status `aberto`). Perguntas ao usuário viram `Q-###` (status `aberto`).
  **Feature não fecha com A-/Q- em aberto** — o gate falha.
- Ao terminar, **confesse na conversa**: liste as suposições e perguntas abertas
  e pergunte; não siga para o plano com A-/Q- em aberto sem o usuário decidir.

Saídas da fase: spec.md legível + criteria.reg/assumptions.reg coerentes.
Confirme o texto com o usuário ANTES de planejar.

---

## Fase 2 — Plano (`/specs-plan`)

- Leia a spec e **divida em tarefas** `T-###`. Para cada:
  - arquivos que a tarefa vai tocar (`- <arquivo>` em tasks/T-###.md) — **disjunção de arquivos = paralelismo seguro**;
  - dependências (`Deps:`, ex. `T-001`),
  - critérios que prova (`ACs:`, ex. `AC-001, AC-002`),
  - comando de verificação da janela (`Run:`).
- Atualize `criteria.reg` ligando cada AC ao seu dono T-###.
- Rode `specs plan-check` → a máquina valida disjunção de arquivos, deps e ciclos. **Não prossiga com saída != 0.**
- Escreva `plan.md` resumindo tarefas/deps/paralelismo.
- **Pergunte ao usuário** (obrigatório, nunca decida sozinho) quais tarefas levar em paralelo:
  - **todas** (as disjuntas rodam lado a lado, cada uma em janela limpa);
  - **algumas** (só as escolhidas em paralelo; o resto uma após a outra na árvore principal);
  - **nenhuma** (tudo na ordem, na árvore principal).
- Apresente como recomendação: *"X dessas tarefas PODEM rodar em paralelo (arquivos disjuntos); quais você quer paralelizar?"*

---

## Fase 3 — Execução (`/specs-run`)

Com a escolha do usuário definida:

1. Para cada tarefa paralela: `specs track <f> <T-id>` → abre janela limpa
   (worktree `trees/F-XXX/<T-id>` + branch `spec/<f>/<T-id>`).
2. Informe o usuário: *"alterações vão rodar em background; a cada minuto posto
   a tabela de andamento."*
3. Rodem em background (linhas de comando em paralelo / sub-tarefas). Dentro de
   cada janela a tarefa: altera só seus arquivos, roda o `Run:` da janela,
   adiciona EXATAMENTE 1 commit com mensagem `T-###: <título>`. Só então chame
   `specs state <f> <T-id> done` (ou `failed`).
4. **A cada ~1 minuto**: rode `specs status <f>` (formato mecânico), transforme
   em **tabela de andamento** (qual roda, qual parou, o que concluiu/falhou)
   e curta um **parágrafo-resumo em PT-BR**.
5. Ao final: resumo completo em PT-BR + próximo passo (integrar/auditar).

Regras da execução:
- 1 tarefa = 1 commit rastreável. `state.tsv` é a única verdade de estado.
- Nunca edite `trace.tsv`, `criteria.reg`, `assumptions.reg` ou `state.tsv` à
  mão enquanto houver execução concorrente — use os comandos `specs prove`,
  `specs resolve`, `specs state` (eles travam a escrita).

### Reexecução de faixa falha (`/specs-redo <T-id>`)
Peça a reação de uma faixa E RECOMEÇA somente ela, do zero, numa janela limpa:
`specs track <f> <T-id> --clean` → roda de novo a tarefa nessa janela nova.
Não toque nas que passaram.

---

## Fase 4 — Integração

- Integre NA ORDEM das dependências: `specs integrate <f> <T-id>`.
  - O comando verifica deps integradas, checa conflito (merge `--no-ff`) e
    remove a janela ao final.
- **Conflito?** O usuário pediu paralelismo — conflito real de arquivos é sinal
  de plano imperfeito. Resolva SEQUENCIALMENTE na árvore principal: integre a
  tarefa de menor prioridade, então a seguinte na ordem. Reprove os critérios
  afetados com `specs prove` depois da resolução. Nunca "resolva" editando o
  trace.tsv à mão.

---

## Fase 5 — Auditoria / prova (`/specs-audit`)

1. `specs proof <f>` → **executável**: roda cada comando de teste registrado em
   `trace.tsv`. O veredito é o **exit code** (0 = PASS, 1 = FAIL).
2. Se a saída for FAIL, é FAIL. **Você não pode declarar vitória.**
   Critique nada: reporte. Corrija → reprove → re-rove.
3. `specs gate <f>` → fecha a feature: exige
   - plano são (`plan-check`),
   - **sem drift spec.md ↔ criteria.reg** (`reconcile`),
   - todas as tarefas integradas,
   - **nenhum worktree órfão vivo** (`trees/`),
   - `proof` com todos os critérios provados e passando,
   - **constituição respeitada** (`constitution scan`),
   - nenhuma A-/Q- em aberto.
   Imprima o `#verdict … PASS|FAIL` por extenso.

### Critérios → teste (a prova)
Para cada AC, registre a prova com
`specs prove <f> <AC-id> "<comando que verdadeiramente testa>" <T-id>`.
O comando roda no diretório raiz do projeto. Teste pulado/inexistente = critério
não provado = gate FAIL.

**Strict (teste pulado não conta):** para critérios onde o runner silencioso
pode "pular" (vitest `describe.skip`, pytest `skip`, `xit`), use
`specs prove --strict …` — o `proof --strict` trata skip como falha mesmo com
exit 0. Use `--strict` no audit quando a feature for crítica.

---

## Constituição (`/specs-constitution`)

- A constituição vive em `.spec/constitution.md` (preset LGPD/educação no init).
- Rode `specs constitution scan` — execute os `<scan>` e mostre o exit code:
  **0 = respeito, 1 = violação** (com arquivo:linha). Feature não fecha com violação.
- Nunca "justifique" violação de constituição executável.

---

## Lições (`/specs-lesson`)

- Registre via `specs lesson add <arquivo.md>`: valida a âncora E anexa em
  `lessons.md` com id `L-####` numerado automaticamente. Sem âncora em falha
  real → exit 2 (recusado, nada é anexado).
- Formato exigido: linha `- Ancora: …` citando AC-/F- E o fracasso (fail/erro).
- Opinião solta não entra; lição ancorada em falha real é que aprende.

---

## Regras nucleares (imutáveis)

1. **Pronto = exit code**, não frase. `proof`/`gate` decidem; você reporta.
2. **Teste pulado não é prova.** Sem `specs prove` registrado com comando
   executável, o critério não existe para a máquina; com `--strict`, skip vira
   falha mesmo com exit 0.
3. **Suposições/perguntas abertas bloqueiam o fechamento.**
4. **1 tarefa = 1 commit**, feito na janela. Nunca "commit de limpeza".
5. **Paralelismo é decisão do usuário**, apresentado como recomendação. Você
   nunca escolhe sozinho; executa com a mesma disciplina e o mesmo gate.
6. **Constituição violada bloqueia.** O gate roda o scan; não há vitória com
   violação (nem com scan não-verificável).
7. **Spec e mecânica não divergem.** AC citada em spec.md mas não em criteria.reg
   (ou vice-versa) é drift e bloqueia o gate (`reconcile`).
8. Responda e produza aparato sempre em **português simples** (salvo IDs/comandos).

## Comandos internos (referência rápida)

| comando | papel |
|--------|-------|
| `specs init [--no-constitution]` | cria projeto .spec/ |
| `specs new <nome> [slug]` | cria feature F-###-<slug> |
| `specs plan-check [<f>]` | audita plano (disjunção, deps, ciclo) |
| `specs track <f> <T-id> [--clean]` | abre/reabre janela limpa |
| `specs state <f> <T-id> <st>` | registra estado sob lock (enum validado) |
| `specs integrate <f> <T-id>` | integra na ordem, checa conflito |
| `specs prove [--strict] <f> <AC-id> <cmd> <T-id>` | registra prova de critério (lock) |
| `specs resolve <f> <id> <status>` | fecha suposição/pergunta (lock) |
| `specs status [<f>]` | tabela mecânica (TSV) para resumos |
| `specs proof [--strict] [<f>]` | veredito executável (exit code) |
| `specs reconcile [<f>]` | drift spec.md ↔ criteria.reg |
| `specs gate <f>` | gate final (plano+drift+integra+worktrees+prova+const+abertas) |
| `specs constitution [scan]` | verifica constituição (exit 1 se violada/não-verificável) |
| `specs lesson <arquivo.md>` | valida âncora de lição (exit 2 se não) |
| `specs lesson add <arquivo.md>` | valida + anexa em lessons.md com L-#### |