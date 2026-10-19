---
description: Revisa as janelas executadas — auto-review mecânico + deep review (6 tipos) + aprovação/rejeição sua antes de integrar.
---

# Specs — Revisa e aprova janelas

Carregue a skill `specs` e execute o fluxo de **revisão em 3 camadas**.

$ARGUMENTS

## Modos
- Sem argumento / com `<f>`: apresenta o **lote final** de revisão — para cada janela
  o diff, o veredito `auto-review` e o relatório `deep review`, e espera sua
  decisão (aprovar/rejeitar) uma a uma.
- `--deep`: roda o **deep review final** sobre o tree integrado (diff acumulado
  contra o base) usando os 6 subagentes `review-*`, e consolida o relatório.

## Passos (modo lote)
1. Liste as janelas prontas com `specs status <f>` (colunas `auto`/`deep`/`fixes`).
2. Para cada janela:
   - `specs review <f> <T-id>` → cole o diff + status (`auto`/`deep`/`fixes`).
   - Deep review por janela (quando ainda `deep=not-run`): lance os subagentes
     `review-security`, `review-performance`, `review-correctness`, `review-quality`,
     `review-tests`, `review-compat` **em paralelo**, escopo = diff
     `git diff <base>...spec/<f>/<T-id>`; consolide relatório único (status +
     findings com severidade `file:line`). Grave: `specs review <f> <T-id> --deep=<verdict>`.
3. **Apresente o relatório** (estilo pull-request): status `APPROVED |
   CHANGES REQUIRED | APPROVED WITH SUGGESTIONS` + tabela de findings.
4. **Auto-fix** se houver `auto-issues` ou `changes-required` (máx. 3 iterações;
   cada iteração registrada com `specs review <f> <T-id> --fixes=1`; sempre
   reporte o que corrigiu e por quê).
5. Espere a **decisão do usuário** para cada janela e grave:
   - `specs review <f> <T-id> --approve` (aprovado — libera `integrate`);
   - `specs review <f> <T-id> --reject` (recusado — não integra).
6. Só então `specs integrate <f> <T-id>` (que verifica approved + sha + auto-ok
   + deep sem changes-required).

Você não declara vitória: **o exit code e a aprovação sua decidem.**