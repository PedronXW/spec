#!/usr/bin/env bash
# specs.sh — motor do fluxo spec-anchored.
# Formato mecânico = TSV (tab). A spec legível vive em spec.md; o traço
# mecânico (critérios x testes x tarefas x estado) vive nos .reg/.tsv.

declare -g SPECS_ROOT SPECS_VERSION

SPECS_SPEC_DIR=".spec"
SPECS_FEATURES_DIR=".spec/features"
SPECS_TREES_DIR=".spec/trees"
SPECS_LOCKS_DIR=".spec/locks"

specs_log() { printf 'specs: %s\n' "$*"; }
specs_err() { printf 'specs: ERRO: %s\n' "$*" >&2; }

# --------------------------------------------------------------- raiz ----

specs_project_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/$SPECS_SPEC_DIR" ]; then printf '%s' "$dir"; return 0; fi
    dir="$(dirname "$dir")"
  done
  return 1
}

specs_require_project() {
  if ! PROJECT_ROOT="$(specs_project_root)"; then
    specs_err "nenhum projeto .spec/ neste diretório ou ancestrais (rode 'specs init')."
    return 1
  fi
  export PROJECT_ROOT
  return 0
}

specs_require_git() {
  command -v git >/dev/null 2>&1 || { specs_err "git não encontrado."; return 1; }
  git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1 || {
    specs_err "$PROJECT_ROOT não é repositório git (worktrees exigem git)."
    return 1
  }
  return 0
}

# -------------------------------------------------------------- travas ----

# R2 — escrita concorrente sempre sob lock. flock quando existe; senão mkdir
# atômico com spin. O caminho -> função roda em subshell (fork herda funções).
with_lock() {
  local name="$1"; shift
  local lockdir="$PROJECT_ROOT/$SPECS_LOCKS_DIR"
  mkdir -p "$lockdir" || return 1

  if command -v flock >/dev/null 2>&1; then
    (
      exec 9>"$lockdir/$name.lock"
      flock 9
      "$@"
    )
    return $?
  fi

  local dir="$lockdir/$name" i=0
  while [ "$i" -lt 300 ]; do
    if mkdir "$dir" 2>/dev/null; then
      "$@"; local rv=$?
      rmdir "$dir" 2>/dev/null || true
      return "$rv"
    fi
    sleep 0.02; i=$((i+1))
  done
  specs_err "lock '$name' esgotou (tempo)." >&2
  return 1
}

# --------------------------------------------------------- localizacao ----

# resolve feature por id ("F-001"), por diretório completo, por prefixo ou
# por nome com/sem barra final
specs_feature_dir() {
  local q="$1" d base
  q="${q%/}"
  case "$q" in
    */*) d="$q"; [ -d "$d" ] && { printf '%s' "$d"; return 0; } ;;
  esac
  for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
    [ -d "$d" ] || continue
    base="$(basename "$d")"
    case "$base" in
      "$q"|"$q-"*|"F-"*/"$q") printf '%s' "${d%/}"; return 0 ;;
    esac
  done
  return 1
}

specs_feature_id() { basename "$1"; }

specs_criteria_file()    { printf '%s/criteria.reg' "$1"; }
specs_trace_file()       { printf '%s/trace.tsv' "$1"; }
specs_assumptions_file() { printf '%s/assumptions.reg' "$1"; }
specs_state_file()       { printf '%s/state.tsv' "$1"; }
specs_reviews_file()     { printf '%s/reviews.reg' "$1"; }
specs_review_dir()       { printf '%s/reviews' "$1"; }
specs_tasks_dir()        { printf '%s/tasks' "$1"; }

# ------------------------------------------------------------ critérios ----

# criteria.reg: AC-id\tU-id\tdescricao\tT-id
specs_criteria_list() {
  local f="$1" file; file="$(specs_criteria_file "$f")"
  [ -f "$file" ] || return 0
  awk -F'\t' 'NF==4 && $1 ~ /^AC-/' "$file"
}

specs_criteria_task_of() {
  local f="$1" ac="$2" file; file="$(specs_criteria_file "$f")"
  [ -f "$file" ] || return 1
  awk -F'\t' -v ac="$ac" '$1==ac{print $4; exit}' "$file"
}

# --------------------------------------------------------------- trace ----

# trace.tsv: AC-id\tcomando-teste\tT-id\tstatus\tsha[\tstrict]
specs_trace_list() {
  local f="$1" file; file="$(specs_trace_file "$f")"
  [ -f "$file" ] || return 0
  awk -F'\t' 'NF>=5 && $1 ~ /^AC-/' "$file"
}

specs_trace_cmd_of() {
  local f="$1" ac="$2" file; file="$(specs_trace_file "$f")"
  [ -f "$file" ] || return 1
  awk -F'\t' -v ac="$ac" '$1==ac{print $2; exit}' "$file"
}

specs_trace_status_of() {
  local f="$1" ac="$2" file; file="$(specs_trace_file "$f")"
  [ -f "$file" ] || return 1
  awk -F'\t' -v ac="$ac" '$1==ac{print $4; exit}' "$file"
}

specs_trace_strict_of() {
  local f="$1" ac="$2" file; file="$(specs_trace_file "$f")"
  [ -f "$file" ] || return 1
  awk -F'\t' -v ac="$ac" '$1==ac{print $6; exit}' "$file"
}

# --------------------------------------------------------- suposições ----

# assumptions.reg: id\ttipo(A|Q)\tstatus\ttexto
specs_assumptions_list() {
  local f="$1" file; file="$(specs_assumptions_file "$f")"
  [ -f "$file" ] || return 0
  awk -F'\t' 'NF==4 && $1 ~ /^[AQ]-/' "$file"
}

# ------------------------------------------------------------------ estado

# state.tsv: T-id\tstatus\tbranch\tsha
specs_state_list() {
  local f="$1" file; file="$(specs_state_file "$f")"
  [ -f "$file" ] || return 0
  awk -F'\t' 'NF==4 && $1 ~ /^T-/' "$file"
}

specs_state_set() {
  local f="$1" tid="$2" status="$3" branch="${4:-}" sha="${5:-}"
  local file; file="$(specs_state_file "$f")"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then printf '#T-id\tstatus\tbranch\tsha\n' > "$file"; fi
  awk -F'\t' -v tid="$tid" -v st="$status" -v br="$branch" -v sh="$sha" '
    BEGIN{OFS="\t"}
    $1==tid { $2=st; $3=br; $4=sh; found=1; print; next }
    { print }
    END{ if(!found) printf "%s\t%s\t%s\t%s\n", tid, st, br, sh }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

specs_state_of() {
  local f="$1" tid="$2" file; file="$(specs_state_file "$f")"
  [ -f "$file" ] || return 1
  awk -F'\t' -v tid="$tid" '$1==tid{print; exit}' "$file"
}

# ------------------------------------------------------------- reviews ----

# reviews.reg: T-id\tstatus(open|approved|rejected)\treviewer\tsha\twhen\tauto\tdeep\tfixes
specs_review_list() {
  local f="$1" file; file="$(specs_reviews_file "$f")"
  [ -f "$file" ] || return 0
  awk -F'\t' 'NF>=8 && $1 ~ /^T-/' "$file"
}

specs_review_of() {
  local f="$1" tid="$2" file; file="$(specs_reviews_file "$f")"
  [ -f "$file" ] || return 1
  awk -F'\t' -v tid="$tid" '$1==tid{print; exit}' "$file"
}

specs_review_field() {
  local f="$1" tid="$2" col="$3"
  specs_review_of "$f" "$tid" | cut -f"$col"
}

# grava/atualiza a linha de revisão de uma tarefa (8 colunas)
specs_review_set() {
  local f="$1" tid="$2" status="$3" reviewer="$4" sha="$5" when="$6" auto="${7:-not-run}" deep="${8:-not-run}" fixes="${9:-0}"
  local file; file="$(specs_reviews_file "$f")"
  mkdir -p "$(dirname "$file")"
  if [ ! -f "$file" ]; then printf '#T-id\tstatus\treviewer\tsha\twhen\tauto\tdeep\tfixes\n' > "$file"; fi
  awk -F'\t' -v tid="$tid" -v st="$status" -v rv="$reviewer" -v sh="$sha" -v wh="$when" -v au="$auto" -v dp="$deep" -v fx="$fixes" '
    BEGIN{OFS="\t"}
    $1==tid { $2=st; $3=rv; $4=sh; $5=wh; $6=au; $7=dp; $8=fx; found=1; print; next }
    { print }
    END{ if(!found) printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", tid, st, rv, sh, wh, au, dp, fx }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

specs_tasks_all() {
  local fdir="$1"; fdir="$(specs_tasks_dir "$fdir")"
  [ -d "$fdir" ] || return 0
  for t in "$fdir"/T-*.md; do
    [ -f "$t" ] || continue
    basename "$t" .md
  done | sort -V
}

# lê campo de um arquivo de tarefa
specs_task_field_value() {
  local taskfile="$1" key="$2"
  grep -m1 -E "^[[:space:]]*[-\*#[:space:]]*${key}\*{0,2}:" "$taskfile" 2>/dev/null \
    | sed "s/^.*${key}\*\{0,2\}:['\"]*//; s/['\"]*[[:space:]]*\$//" \
    | sed 's/^\*\*//; s/^\*//; s/\*\*$//; s/\*$//; s/^[[:space:]]*//'
}

specs_task_field() {
  case "$2" in
    files) sed -n 's/^[[:space:]]*-\s\+\([^*#][^[:space:]]*\)[[:space:]]*$/\1/p' "$1" ;;
    deps)  specs_task_field_value "$1" "Deps" ;;
    ac)    specs_task_field_value "$1" "ACs" ;;
    run)   specs_task_field_value "$1" "Run" ;;
  esac
}

specs_branch_of() { printf 'spec/%s/%s' "$(specs_feature_id "$1")" "$2"; }

# ------------------------------------------------------------ CLI --------

specs_find_feature() {
  local arg="${1:-}" fd
  if [ -z "$arg" ]; then
    for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
      [ -d "$d" ] || continue
      printf '%s' "$d"; return 0
    done
    return 1
  fi
  # caminho direto
  if [ -d "$PROJECT_ROOT/$SPECS_FEATURES_DIR/$arg" ]; then
    printf '%s/%s' "$PROJECT_ROOT/$SPECS_FEATURES_DIR" "$arg"; return 0
  fi
  specs_feature_dir "$arg"
}

specs_usage() {
  cat <<'EOF'
specs — CLI interno do fluxo spec-anchored (quem executa é o AGENTE).

USO:
  specs init [--no-constitution]       cria .spec/ no diretório atual
  specs new <nome feature> [<slug>]    cria F-XXX-<slug> + esqueleto
  specs plan-check [<f>]               auditoria mecânica do plano
  specs track <f> <T-id> [--clean]     abre janela limpa (worktree+branch)
  specs state <f> <T-id> <status> [branch [sha]]   atualiza estado (lock)
  specs integrate <f> <T-id>           integra janela (deps + dry-merge)
  specs auto-review <f> <T-id>         veredito MECÂNICO da janela (6 checks, exit code)
  specs review <f> <T-id>              mostra diff + status de revisão
  specs review <f> <T-id> --approve|--reject   grava decisão sua (lock)
  specs prove [--strict] <f> <AC-id> <cmd> <T-id>   registra prova de critério (lock)
  specs resolve <f> <id> <status>      fecha suposição/pergunta (lock)
  specs status [<f>]                   tabela mecânica TSV de andamento
  specs proof [--strict] [<f>]         executa TODAS as provas -> exit code
  specs gate <f>                       gate final (plano+integra+prova+const+reconcile+revisão+abertas)
  specs reconcile [<f>]                drift spec.md <-> criteria.reg
  specs constitution [scan]            rode verificações executáveis
  specs lesson <arquivo.md>            recusa lição sem âncora real (exit 2)
  specs lesson add <arquivo.md>        valida e anexa com L-#### automático
  specs help

ESTADOS DE TAREFA: planned | running | done | failed | integrated
REVISÃO: status(open|approved|rejected) · auto(not-run|auto-ok|auto-issues) · deep(not-run|approved|approved-suggestions|changes-required) · fixes(n)
STRICT: teste pulado (skip) não conta como prova (falha mesmo com rc=0)

FORMATOS (tab=\t):
  criteria.reg:     AC-id	U-id	descricao	T-id
  trace.tsv:        AC-id	comando-teste	T-id	status	sha	[strict]
  assumptions.reg:  id	tipo(A|Q)	status	texto
  state.tsv:        T-id	status	branch	sha
  reviews.reg:      T-id	status	reviewer	sha	when	auto	deep	fixes
EOF
}

specs_main() {
  local cmd="${1:-help}"; shift || true
  case "$cmd" in
    help|-h|--help) specs_usage; return 0 ;;
    version|-V)     printf 'specs %s\n' "$SPECS_VERSION"; return 0 ;;
    init)           specs_cmd_init "$@" ;;
    new)            specs_cmd_new "$@" ;;
    plan-check)     specs_cmd_plan_check "$@" ;;
    track)          specs_cmd_track "$@" ;;
    state)          specs_cmd_state "$@" ;;
    integrate)      specs_cmd_integrate "$@" ;;
    auto-review)    specs_cmd_auto_review "$@" ;;
    review)         specs_cmd_review "$@" ;;
    prove)          specs_cmd_prove "$@" ;;
    resolve)        specs_cmd_resolve "$@" ;;
    status)         specs_cmd_status "$@" ;;
    proof)          specs_cmd_proof "$@" ;;
    gate)           specs_cmd_gate "$@" ;;
    reconcile)      specs_cmd_reconcile "$@" ;;
    constitution)   specs_cmd_constitution "$@" ;;
    lesson)         specs_cmd_lesson "$@" ;;
    *)
      specs_err "comando desconhecido: '$cmd'"
      specs_usage >&2
      return 2 ;;
  esac
}