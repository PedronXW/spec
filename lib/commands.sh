#!/usr/bin/env bash
# commands.sh — implementação dos subcomandos `specs`.

# ------------------------------------------------------------ UID/helpers

specs_slug() {
  local s="$1"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
  s="$(printf '%s' "$s" | sed 's/[^a-z0-9]/-/g; s/-\+/-/g; s/^-//; s/-$//')"
  [ -n "$s" ] || s="feature"
  printf '%s' "$s"
}

specs_next_feature_id() {
  local max=0 d id n
  for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
    [ -d "$d" ] || continue
    id="$(basename "$d")"
    n="$(printf '%s' "$id" | sed -n 's/^F-\([0-9]*\).*/\1/p')"
    [ -n "$n" ] && [ "$n" -gt "$max" ] && max="$n"
  done
  printf 'F-%03d' $((max+1))
}

# --------------------------------------------------------------- spec init

specs_cmd_init() {
  if [ -d "$PWD/$SPECS_SPEC_DIR" ]; then
    specs_log ".spec/ já existe em $PWD — nada a criar."
    return 0
  fi
  local no_constitution=0
  while [ "$#" -gt 0 ]; do
    case "$1" in --no-constitution) no_constitution=1 ;; esac; shift
  done

  mkdir -p "$PWD/$SPECS_FEATURES_DIR" "$PWD/$SPECS_TREES_DIR" "$PWD/$SPECS_LOCKS_DIR" || return 1

cat > "$PWD/$SPECS_SPEC_DIR/.gitignore" <<'EOF'
# artefatos gerados — nunca versionar
trees/
locks/
EOF

  mkdir -p "$PWD/$SPECS_FEATURES_DIR"
  cat > "$PWD/$SPECS_FEATURES_DIR/README.md" <<'EOF'
# Features spec-anchored

Cada feature vive em `F-XXX-<slug>/`. Dentro dela:

- `spec.md` — spec LEGÍVEL: histórias `U-###`, critérios `AC-###` (refs),
  suposições `A-###` e perguntas `Q-###`.
- `plan.md` — plano: tarefas `T-###`, deps, paralelismo.
- `criteria.reg` — máquina: `AC-id	U-id	descricao	T-id`.
- `assumptions.reg` — máquina: `id	tipo(A|Q)	status	texto`.
- `trace.tsv` — máquina: `AC-id	comando-teste	T-id	status	sha`.
- `state.tsv` — máquina: `T-id	status	branch	sha`.
- `tasks/T-XXX.md` — janela de execução por tarefa.

Todo critério tem DONO de tarefa. Toda tarefa tem janela (worktree+branch)
própria quando executada em paralelo. "Pronto" = veredito da máquina (`specs proof`).
EOF

  if [ "$no_constitution" -eq 1 ]; then
    cat > "$PWD/$SPECS_SPEC_DIR/constitution.md" <<'EOF'
# Constituição do projeto

> Vazio por opção (--no-constitution). Adicione regras com verificação
> executável (`- scan: <comando>`) e rode `specs constitution scan`.
EOF
  elif [ -f "$SPECS_ROOT/constitution-presets/lgpd-educacao.md" ]; then
    cp "$SPECS_ROOT/constitution-presets/lgpd-educacao.md" "$PWD/$SPECS_SPEC_DIR/constitution.md"
  else
    cat > "$PWD/$SPECS_SPEC_DIR/constitution.md" <<'EOF'
# Constituição do projeto

## C-CORE-001 — Sem credenciais no repositório
- scan: rg -n "(api[_-]?key|secret|password|token)\s*[:=]\s*['\"][^'\"]+['\"]" .

## C-CORE-002 — Sem TODO sem-dono
- scan: rg -n "TODO|FIXME|XXX" .
EOF
  fi

cat > "$PWD/$SPECS_SPEC_DIR/lessons.md" <<'EOF'
# Lições aprendidas (com lastro)

> Só entra lição ANCORADA em falha real. Sem âncora, `specs lesson` recusa.

## L-#### — título
- Ancora: <fonte da falha real> — critério AC-… falhou na feature …
- Lição: <o que aprendemos>
EOF

  specs_log "projeto iniciado em $PWD/.spec"
  printf 'criado: .spec/constitution.md\n'
  printf 'criado: .spec/lessons.md\n'
  printf 'criado: .spec/features/\n'
  printf 'criado: .spec/trees/ e .spec/locks/ (ignorados pelo git)\n'
  return 0
}

# --------------------------------------------------------------- spec new

specs_cmd_new() {
  specs_require_project || return 1
  local nome="${1:-}" slug="${2:-}"
  if [ -z "$nome" ]; then
    specs_err "use: specs new <nome da feature> [<slug>]"
    return 1
  fi
  [ -n "$slug" ] || slug="$(specs_slug "$nome")"

  local fid; fid="$(specs_next_feature_id)"
  local fdir="$PROJECT_ROOT/$SPECS_FEATURES_DIR/$fid-$slug"
  mkdir -p "$fdir/tasks" || return 1

  cat > "$fdir/spec.md" <<EOF
# $fid — $nome

## Histórias de usuário
- <U-001> **Como** um <ator>, **quero** <algo>, **para** <motivo>.

## Critérios de aceite
> Critérios são registrados mecanicamente (AC-### → story → semântica técnica → dono T-###)
> — edite \`criteria.reg\` e reflita aqui por legibilidade ponto a ponto.

- AC-001 — [U-001]
- AC-002 — [U-001]

## Suposições (status: aberto|confirmada|rejeitada)
- A-001 — (texto) — aberto

## Perguntas em aberto
- Q-001 — (texto)
EOF

  cat > "$fdir/tasks/T-001.md" <<'EOF'
# T-001 — primeira tarefa

- **ACs:** AC-001
- **Deps:**
- **Files:**
- **Run:** <comando de verificação desta janela>

## Instruções
- Sempre deixe a janela de trabalho limpa ao terminar.
EOF

  printf '#AC-id\tU-id\tdescricao\tT-id\n' > "$fdir/criteria.reg"
  printf '#AC-id\tcomando-teste\tT-id\tstatus\tsha\n' > "$fdir/trace.tsv"
  printf '#id\ttipo\tstatus\ttexto\n' > "$fdir/assumptions.reg"
  printf '#T-id\tstatus\tbranch\tsha\n' > "$fdir/state.tsv"

  specs_log "criada feature $fid-$slug em $fdir"
  printf 'edite: %s/spec.md\n' "$fdir"
  printf 'edite: %s/criteria.reg\n' "$fdir"
  return 0
}

# -------------------------------------------------------- spec plan-check

specs_cmd_plan_check() {
  specs_require_project || return 1
  local mode="${1:-.}"

  # resolve features: "." => todas
  local feats=()
  if [ "$mode" = "." ]; then
    for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
      [ -d "$d" ] || continue
      feats+=("$d")
    done
  else
    local fd; fd="$(specs_feature_dir "$mode")"
    if [ -z "$fd" ]; then
      specs_err "feature não encontrada: $mode"
      return 1
    fi
    feats+=("$fd")
  fi

  [ "${#feats[@]}" -gt 0 ] || { specs_err "nenhuma feature — rode 'specs new'."; return 1; }

  local overall=0
  for f in "${feats[@]}"; do
    specs_plan_check_one "$f" || overall=1
  done
  return $overall
}

specs_plan_check_one() {
  local fdir="$1"
  local fid; fid="$(specs_feature_id "$fdir")"
  local tdir; tdir="$(specs_tasks_dir "$fdir")"
  local failed=0

  printf 'specs: plan-check %s\n' "$fid"

  # -- AC cobertos por critérios definidos?
  local tx
  if [ -f "$fdir/trace.tsv" ]; then
    while IFS=$'\t' read -r ac _ _ st _; do
      [ "$ac" = "AC-id" ] && continue
      case "$ac" in \#*) continue ;; esac
      [ "$st" = "proven" ] && continue
      printf '  WARN: %s com status "%s" (ainda não provado)\n' "$ac" "$st"
    done < "$fdir/trace.tsv"
  fi

  # -- arquivos disjuntos entre tarefas
  local -A owner=()
  local t
  for t in "$tdir"/T-*.md; do
    [ -f "$t" ] || continue
    local tid; tid="$(basename "$t" .md)"
    while IFS= read -r fp; do
      fp="$(printf '%s' "$fp" | sed 's/[[:space:]]//g')"
      [ -z "$fp" ] && continue
      if [ -n "${owner[$fp]+x}" ]; then
        printf '  ERRO: conflito de arquivos — %s (%s) também usado por %s\n' "$fp" "$tid" "${owner[$fp]}"
        failed=1
      else
        owner["$fp"]="$tid"
      fi
    done < <(specs_task_field "$t" files)
  done

  # -- dependências acessíveis + sem ciclo
  local -A taskset=()
  for t in "$tdir"/T-*.md; do
    [ -f "$t" ] || continue
    taskset["$(basename "$t" .md)"]=1
  done

  for t in "$tdir"/T-*.md; do
    [ -f "$t" ] || continue
    local tid deps d
    tid="$(basename "$t" .md)"
    deps="$(specs_task_field "$t" deps | tr ',' ' ')"
    for d in $deps; do
      [ -z "$d" ] && continue
      if [ -z "${taskset[$d]+x}" ]; then
        printf '  ERRO: %s depende de %s que não existe\n' "$tid" "$d"
        failed=1
      fi
    done
  done

  # detectar ciclo simples (DFS-proxy: proporção de "já expandido")
  local depth=0 changed=1
  local -A expanded=()
  while [ "$changed" -eq 1 ] && [ "$depth" -lt 50 ]; do
    changed=0; depth=$((depth+1))
    for t in "$tdir"/T-*.md; do
      [ -f "$t" ] || continue
      local tid deps d allok=1
      tid="$(basename "$t" .md)"
      [ -n "${expanded[$tid]+x}" ] && continue
      deps="$(specs_task_field "$t" deps | tr ',' ' ')"
      for d in $deps; do
        [ -z "$d" ] && continue
        if [ -z "${expanded[$d]+x}" ] && [ "$d" != "$tid" ]; then allok=0; fi
      done
      if [ "$allok" -eq 1 ]; then expanded["$tid"]=1; changed=1; fi
    done
  done
  for t in "$tdir"/T-*.md; do
    [ -f "$t" ] || continue
    local tid; tid="$(basename "$t" .md)"
    if [ -z "${expanded[$tid]+x}" ]; then
      printf '  ERRO: possível ciclo (ou dep ausente) envolvendo %s\n' "$tid"
      failed=1
    fi
  done

  [ "$failed" -eq 0 ] && printf '  ok — arquivos disjuntos, deps válidas, sem ciclo.\n'
  return $failed
}

# -------------------------------------------------------- spec track

specs_track_open() {
  local root="$1" branch="$2" tree="$3" clean="$4"
  cd "$root" || return 1
  if [ "$clean" = "1" ]; then
    git worktree remove --force "$tree" 2>/dev/null || true
    git branch -D "$branch" 2>/dev/null || true
  fi
  if git rev-parse --verify --quiet "$branch" >/dev/null; then
    printf 'specs: aviso: branch %s já existe (janela já aberta).\n' "$branch" >&2
    return 0
  fi
  mkdir -p "$(dirname "$tree")"
  git worktree add -b "$branch" "$tree" HEAD
}

specs_cmd_track() {
  specs_require_project || return 1
  specs_require_git || return 1

  local clean=0 i a
  for a in "$@"; do [ "$a" = "--clean" ] && clean=1; done
  # remove flags para chegar aos posicionais
  local args=()
  for a in "$@"; do [ "$a" = "--clean" ] || args+=("$a"); done
  local f="${args[0]:-}" tid="${args[1]:-}"
  if [ -z "$f" ] || [ -z "$tid" ]; then
    specs_err "use: specs track <f> <T-id> [--clean]"
    return 1
  fi
  local fdir; fdir="$(specs_feature_dir "$f")"
  [ -n "$fdir" ] || { specs_err "feature não encontrada: $f"; return 1; }
  local tdir; tdir="$(specs_tasks_dir "$fdir")"
  [ -f "$tdir/$tid.md" ] || { specs_err "tarefa não encontrada: $tid (arquivo $tdir/$tid.md ausente)."; return 1; }

  local branch tree
  branch="$(specs_branch_of "$fdir" "$tid")"
  tree="$PROJECT_ROOT/$SPECS_TREES_DIR/$(specs_feature_id "$fdir")/$tid"

  with_lock "track" specs_track_open "$PROJECT_ROOT" "$branch" "$tree" "$clean"
  local rc=$?
  [ "$rc" -eq 0 ] || { specs_err "falha ao abrir janela (rc=$rc)."; return "$rc"; }

  local sha
  if [ -d "$tree" ]; then
    sha="$(git -C "$tree" rev-parse --short HEAD 2>/dev/null || echo "-")"
  else
    sha="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "-")"
  fi
  with_lock "state" specs_state_set "$fdir" "$tid" "running" "$branch" "$sha"
  printf 'specs: janela %s aberta em %s (branch %s)\n' "$tid" "$tree" "$branch"
  return 0
}

# -------------------------------------------------------- spec integrate

specs_integrate_merge() {
  local root="$1" branch="$2"
  cd "$root" || return 1
  local out
  out="$(git merge --no-ff --no-edit "$branch" 2>&1)"
  local rv=$?
  if [ "$rv" -ne 0 ]; then
    printf 'specs: CONFLITO no merge de %s\n%s\n' "$branch" "$out" >&2
    git merge --abort 2>/dev/null || true
  fi
  return "$rv"
}

specs_cmd_integrate() {
  specs_require_project || return 1
  specs_require_git || return 1

  local f="${1:-}" tid="${2:-}"
  if [ -z "$f" ] || [ -z "$tid" ]; then
    specs_err "use: specs integrate <f> <T-id>"
    return 1
  fi
  local fdir; fdir="$(specs_feature_dir "$f")"
  [ -n "$fdir" ] || { specs_err "feature não encontrada: $f"; return 1; }
  local branch; branch="$(specs_branch_of "$fdir" "$tid")"
  local tree="$PROJECT_ROOT/$SPECS_TREES_DIR/$(specs_feature_id "$fdir")/$tid"

  # dependências devem estar integradas antes
  local tdir deps d
  tdir="$(specs_tasks_dir "$fdir")"
  deps="$(specs_task_field "$tdir/$tid.md" deps | tr ',' ' ')"
  for d in $deps; do
    [ -z "$d" ] && continue
    local dstatus; dstatus="$(specs_state_of "$fdir" "$d" | cut -f2)"
    if [ "$dstatus" != "integrated" ]; then
      specs_err "dependência %s ainda não integrada (status=%s). Integre na ordem." "$d" "$dstatus"
      return 1
    fi
  done

  if ! git rev-parse --verify --quiet "$branch" >/dev/null; then
    specs_err "branch %s não existe. Abra com 'specs track'." "$branch"
    return 1
  fi

  local tree_sha main_sha
  tree_sha="$(git -C "$PROJECT_ROOT" rev-parse --short "$branch")"
  main_sha="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"
  if [ "$tree_sha" = "$main_sha" ]; then
    specs_err "janela %s não tem commits novos — finalize e commite a tarefa na janela antes de integrar." "$tid"
    return 1
  fi

  with_lock "integrate" specs_integrate_merge "$PROJECT_ROOT" "$branch"
  local rv=$?
  if [ "$rv" -eq 3 ]; then return 3; fi
  [ "$rv" -eq 0 ] || return "$rv"
  local sha; sha="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD)"

  # remove a janela (já mergeada)
  if [ -d "$tree" ]; then git -C "$PROJECT_ROOT" worktree remove --force "$tree" 2>/dev/null || true; fi
  git -C "$PROJECT_ROOT" branch -D "$branch" 2>/dev/null || true

  with_lock "state" specs_state_set "$fdir" "$tid" "integrated" "" "$sha"
  printf 'specs: %s integrado em main (sha %s). Janela removida.\n' "$tid" "$sha"
  return 0
}

# -------------------------------------------------------- spec state

specs_cmd_state() {
  specs_require_project || return 1
  local f="${1:-}" tid="${2:-}" status="${3:-}"
  if [ -z "$f" ] || [ -z "$tid" ] || [ -z "$status" ]; then
    specs_err "use: specs state <f> <T-id> <status> [branch [sha]]"
    return 1
  fi
  case "$status" in
    planned|running|done|failed|integrated) : ;;
    *)
      specs_err "status inválido '$status' — use: planned|running|done|failed|integrated"
      return 1 ;;
  esac
  local fdir; fdir="$(specs_feature_dir "$f")"
  [ -n "$fdir" ] || { specs_err "feature não encontrada: $f"; return 1; }
  local branch="${4:-}" sha="${5:-}"
  with_lock "state" specs_state_set "$fdir" "$tid" "$status" "$branch" "$sha"
  printf 'specs: %s -> %s\n' "$tid" "$status"
}

# -------------------------------------------------------- spec prove

specs_trace_upsert() {
  # $1=trace file $2=ac $3=cmd $4=tid $5=sha $6=strict(0|1)
  local trace="$1" ac="$2" cmd="$3" tid="$4" sha="$5" strict="${6:-0}"
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v ac="$ac" -v cmd="$cmd" -v tid="$tid" -v sha="$sha" -v strict="$strict" '
    BEGIN{OFS="\t"}
    $1==ac { $2=cmd; $3=tid; $4="proven"; $5=sha; $6=strict; found=1; print; next }
    { print }
    END{ if(!found) printf "%s\t%s\t%s\t%s\t%s\t%s\n", ac, cmd, tid, "proven", sha, strict }
  ' "$trace" > "$tmp"
  mv "$tmp" "$trace"
}

specs_cmd_prove() {
  specs_require_project || return 1
  local strict=0
  for a in "$@"; do [ "$a" = "--strict" ] && strict=1; done
  local args=()
  for a in "$@"; do [ "$a" = "--strict" ] || args+=("$a"); done
  local f="${args[0]:-}" ac="${args[1]:-}" cmd="${args[2]:-}" tid="${args[3]:-}"
  if [ -z "$f" ] || [ -z "$ac" ] || [ -z "$cmd" ] || [ -z "$tid" ]; then
    specs_err "use: specs prove [--strict] <f> <AC-id> <comando-teste> <T-id>"
    return 1
  fi
  local fdir; fdir="$(specs_feature_dir "$f")"
  [ -n "$fdir" ] || { specs_err "feature não encontrada: $f"; return 1; }

  # o critério DEVE existir em criteria.reg
  local task; task="$(specs_criteria_task_of "$fdir" "$ac")"
  if [ -z "$task" ]; then
    specs_err "critério %s não registrado em criteria.reg — registre antes de provar." "$ac"
    return 1
  fi

  local trace; trace="$(specs_trace_file "$fdir")"
  if [ ! -f "$trace" ]; then printf '#AC-id\tcomando-teste\tT-id\tstatus\tsha\tstrict\n' > "$trace"; fi

  local sha; sha="$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo '-')"

  with_lock "trace" specs_trace_upsert "$trace" "$ac" "$cmd" "$tid" "$sha" "$strict"
  printf 'specs: %s provado por: %s%s\n' "$ac" "$cmd" "$([ "$strict" = "1" ] && echo ' (strict: teste pulado = falha)')"
  return 0
}

# -------------------------------------------------------- spec resolve

specs_assumption_upsert() {
  # $1=file $2=id $3=status
  local file="$1" id="$2" st="$3"
  local tmp; tmp="$(mktemp)"
  awk -F'\t' -v id="$id" -v st="$st" '
    BEGIN{OFS="\t"}
    $1==id { $3=st; found=1; print; next }
    { print }
    END{ if(!found){ printf "id %s: não encontrado\n", id | "cat >&2"; exit 1 } }
  ' "$file" > "$tmp"
  local rv=$?
  if [ "$rv" -eq 0 ]; then mv "$tmp" "$file"; else rm -f "$tmp"; fi
  return "$rv"
}

specs_cmd_resolve() {
  specs_require_project || return 1
  local f="${1:-}" id="${2:-}" status="${3:-}"
  if [ -z "$f" ] || [ -z "$id" ] || [ -z "$status" ]; then
    specs_err "use: specs resolve <f> <id> <confirmed|rejected|answered>"
    return 1
  fi
  case "$status" in
    confirmed|rejected|answered) : ;;
    *) specs_err "status inválido '$status' (use confirmed|rejected|answered)."; return 1 ;;
  esac
  local fdir; fdir="$(specs_feature_dir "$f")"
  [ -n "$fdir" ] || { specs_err "feature não encontrada: $f"; return 1; }

  local file; file="$(specs_assumptions_file "$fdir")"
  if [ ! -f "$file" ]; then printf '#id\ttipo\tstatus\ttexto\n' > "$file"; fi

  with_lock "assump" specs_assumption_upsert "$file" "$id" "$status"
  local rv=$?
  if [ "$rv" -eq 0 ]; then printf 'specs: %s -> %s\n' "$id" "$status"; fi
  return "$rv"
}

# -------------------------------------------------------- spec status

specs_cmd_status() {
  specs_require_project || return 1
  local filter="${1:-}"
  printf '#specs\t%s\n' "$SPECS_VERSION"

  local d
  for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
    [ -d "$d" ] || continue
    local fid; fid="$(specs_feature_id "$d")"
    if [ -n "$filter" ]; then
      case "$fid" in "$filter"|"$filter-"*) : ;; *) continue ;; esac
    fi

    printf '#feature\t%s\n' "$fid"

    # tarefas
    local t
    for t in "$(specs_tasks_dir "$d")"/T-*.md; do
      [ -f "$t" ] || continue
      local tid st br sha deps acs
      tid="$(basename "$t" .md)"
      st="$(specs_state_of "$d" "$tid" | cut -f2)"; [ -z "$st" ] && st="planned"
      br="$(specs_state_of "$d" "$tid" | cut -f3)"
      sha="$(specs_state_of "$d" "$tid" | cut -f4)"
      deps="$(specs_task_field "$t" deps)"
      acs="$(specs_task_field "$t" ac)"
      printf 'T\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$fid" "$tid" "$st" "${br:-"-"}" "${sha:-"-"}" "${deps:-"-"}" "${acs:-"-"}"
    done

    # critérios
    if [ -f "$d/criteria.reg" ]; then
      local crit
      while IFS=$'\t' read -r ac u desc towner; do
        [ "$ac" = "AC-id" ] && continue
        case "$ac" in \#*) continue ;; esac
        local pst; pst="$(specs_trace_status_of "$d" "$ac")"; [ -z "$pst" ] && pst="unproven"
        printf 'AC\t%s\t%s\t%s\t%s\t%s\n' "$fid" "$ac" "$u" "$pst" "${towner:-"-"}"
      done < "$d/criteria.reg"
    else
      printf 'AC\t%s\t<none>\t-\t-\t-\n' "$fid"
    fi

    # suposições/abertas
    if [ -f "$d/assumptions.reg" ]; then
      local a
      while IFS=$'\t' read -r id tipo sttxt resto; do
        [ "$id" = "id" ] && continue
        case "$id" in \#*) continue ;; esac
        printf 'AQ\t%s\t%s\t%s\t%s\n' "$fid" "$id" "$sttxt" "${resto:-"-"}"
      done < "$d/assumptions.reg"
    fi
  done
  return 0
}

# -------------------------------------------------------- spec proof

specs_cmd_proof() {
  specs_require_project || return 1
  local strict=0 filter=""
  for a in "$@"; do
    case "$a" in --strict) strict=1 ;; *) filter="$a" ;; esac
  done
  local overall=0

  if [ -n "$filter" ]; then
    local fd; fd="$(specs_feature_dir "$filter")"
    if [ -z "$fd" ]; then specs_err "feature não encontrada: $filter"; return 1; fi
    specs_proof_one "$fd" "$strict" || overall=1
  else
    local d
    for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
      [ -d "$d" ] || continue
      specs_proof_one "$d" "$strict" || overall=1
    done
  fi

  if [ "$overall" -eq 0 ]; then
    printf 'specs: PROVA VERDITO: PASS (exit 0)\n'
  else
    printf 'specs: PROVA VERDITO: FAIL (exit 1)\n'
  fi
  return $overall
}

specs_proof_one() {
  local fdir="$1" force_strict="${2:-0}"
  local fid; fid="$(specs_feature_id "$fdir")"
  local trace; trace="$(specs_trace_file "$fdir")"
  local failed=0

  printf 'specs: proof %s\n' "$fid"
  if [ ! -f "$trace" ]; then
    printf '  FAIL: nenhum trace.tsv — feature sem critério provado.\n'
    return 1
  fi

  local all_crit_ids
  all_crit_ids="$(awk -F'\t' '$1 ~ /^AC-/{print $1}' "$fdir/criteria.reg" 2>/dev/null)"
  local prov_ids
  prov_ids="$(awk -F'\t' '$1 ~ /^AC-/{print $1}' "$trace")"

  # 1. critérios DEVE ter prova registrada
  if [ -n "$all_crit_ids" ]; then
    local ac
    while IFS= read -r ac; do
      [ -z "$ac" ] && continue
      if ! printf '%s\n' "$prov_ids" | grep -qx "$ac"; then
        printf '  FAIL: %s sem prova registrada (nenhuma linha em trace.tsv)\n' "$ac"
        failed=1
      fi
    done <<< "$all_crit_ids"
  else
    printf '  WARN: criteria.reg vazio — sem critérios para auditar.\n'
  fi

  # 2. executar cada comando de teste registrado como proven
  local have_timeout=0
  command -v timeout >/dev/null 2>&1 && have_timeout=1
  while IFS=$'\t' read -r ac cmd tid st sha strict; do
    [ "$ac" = "AC-id" ] && continue
    [ "$st" = "proven" ] || continue
    [ -n "$strict" ] || strict=0
    if [ -z "$cmd" ]; then
      printf '  FAIL: %s registrado proven mas sem comando de teste\n' "$ac"
      failed=1; continue
    fi
    printf '  RUN  %s -> %s\n' "$ac" "$cmd"
    local runrc out
    if [ "$have_timeout" -eq 1 ]; then
      out="$(cd "$PROJECT_ROOT" && timeout 300 bash -c "$cmd" 2>&1)"
      runrc=$?
    else
      out="$(cd "$PROJECT_ROOT" && bash -c "$cmd" 2>&1)"
      runrc=$?
    fi
    # A2 — strict: teste pulado não é prova. Skip de runner = falha mesmo rc=0.
    local is_strict=0
    if [ "$force_strict" = "1" ] || [ "$strict" = "1" ]; then is_strict=1; fi
    if [ "$is_strict" = "1" ] && [ "$runrc" -eq 0 ]; then
      if printf '%s' "$out" | grep -qiE 'skip(ped)?|pulad|pending|xit\b|it\.skip|describe\.skip|pytest\.mark\.skip|@Disabled|DISABLED'; then
        printf '  FAIL %s (STRICT: saída indica teste pulado/skip — pulado não conta como prova)\n' "$ac"
        failed=1
        continue
      fi
    fi
    if [ "$runrc" -eq 0 ]; then
      printf '  PASS %s\n' "$ac"
    else
      printf '  FAIL %s (comando retornou != 0): %s\n' "$ac" "$cmd"
      failed=1
    fi
  done < "$trace"

  return $failed
}

# -------------------------------------------------------- spec reconcile

# B4 — drift-check entre spec.md (legível) e criteria.reg (mecânico).
specs_cmd_reconcile() {
  specs_require_project || return 1
  local filter="${1:-}"
  local overall=0

  local d
  if [ -n "$filter" ]; then
    d="$(specs_feature_dir "$filter")"
    if [ -z "$d" ]; then specs_err "feature não encontrada: $filter"; return 1; fi
    specs_reconcile_one "$d" || overall=1
  else
    for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
      [ -d "$d" ] || continue
      specs_reconcile_one "$d" || overall=1
    done
  fi

  if [ "$overall" -eq 0 ]; then
    printf '#verdict\treconcile\tPASS\n'
  else
    printf '#verdict\treconcile\tDRIFT\n'
  fi
  return $overall
}

specs_reconcile_one() {
  local fdir="$1"
  local fid; fid="$(specs_feature_id "$fdir")"
  local failed=0

  # tokens AC- em spec.md
  local spec_acs reg_acs
  spec_acs="$(grep -oE '\bAC-[0-9]+' "$fdir/spec.md" 2>/dev/null | sort -u)"
  reg_acs="$(awk -F'\t' '$1 ~ /^AC-/{print $1}' "$fdir/criteria.reg" 2>/dev/null | sort -u)"

  local ac
  # AC em spec.md mas não registrado -> drift
  while IFS= read -r ac; do
    [ -z "$ac" ] && continue
    if ! printf '%s\n' "$reg_acs" | grep -qx "$ac"; then
      printf 'specs: %s — DRIFT: %s citado em spec.md mas não registrado em criteria.reg\n' "$fid" "$ac"
      failed=1
    fi
  done <<< "$spec_acs"
  # AC registrado mas não citado na spec -> drift (orienta a spec)
  while IFS= read -r ac; do
    [ -z "$ac" ] && continue
    if ! printf '%s\n' "$spec_acs" | grep -qx "$ac"; then
      printf 'specs: %s — DRIFT: %s registrado em criteria.reg mas ausente de spec.md\n' "$fid" "$ac"
      failed=1
    fi
  done <<< "$reg_acs"

  return $failed
}

# -------------------------------------------------------- spec gate

specs_cmd_gate() {
  specs_require_project || return 1
  local f="${1:-.}"
  local failed=0

  # 1. plano são
  if ! specs_cmd_plan_check "$f" >/dev/null 2>&1; then
    printf 'specs: GATE FAIL — plano com problemas.\n'
    specs_cmd_plan_check "$f"
    failed=1
  fi

  # 1.5. drift spec.md <-> criteria.reg (B4)
  if ! specs_cmd_reconcile "$f" >/dev/null 2>&1; then
    printf 'specs: GATE FAIL — drift entre spec.md e criteria.reg.\n'
    specs_cmd_reconcile "$f"
    failed=1
  fi

  # 2. todas as tarefas integradas
  local feats=()
  if [ "$f" = "." ]; then
    for d in "$PROJECT_ROOT/$SPECS_FEATURES_DIR"/F-*/; do
      [ -d "$d" ] || continue
      feats+=("$d")
    done
  else
    local fd; fd="$(specs_feature_dir "$f")"
    [ -n "$fd" ] || { specs_err "feature não encontrada: $f"; return 1; }
    feats+=("$fd")
  fi

  for fdir in "${feats[@]}"; do
    local fid; fid="$(specs_feature_id "$fdir")"
    for t in "$(specs_tasks_dir "$fdir")"/T-*.md; do
      [ -f "$t" ] || continue
      local tid st; tid="$(basename "$t" .md)"
      st="$(specs_state_of "$fdir" "$tid" | cut -f2)"; [ -z "$st" ] && st="planned"
      if [ "$st" != "integrated" ]; then
        printf 'specs: GATE FAIL — %s ainda %s (não integrada)\n' "$fid/$tid" "$st"
        failed=1
      fi
    done
  done

  # 2.5. worktrees órfãos (A3) — nenhuma janela viva para as features
  specs_gate_orphan_check "${feats[@]}" || failed=1

  # 3. prova mecânica
  if [ "$f" = "." ]; then
    specs_cmd_proof || failed=1
  else
    specs_cmd_proof "$f" || failed=1
  fi

  # 3.5. constituição (A1)
  if ! specs_cmd_constitution scan >/dev/null 2>&1; then
    printf 'specs: GATE FAIL — constituição violada ou não verificável.\n'
    specs_cmd_constitution scan
    failed=1
  fi

  # 4. sem suposições/perguntas em aberto
  for fdir in "${feats[@]}"; do
    local fid; fid="$(specs_feature_id "$fdir")"
    if [ ! -f "$fdir/assumptions.reg" ]; then continue; fi
    local id tipo st
    while IFS=$'\t' read -r id tipo st _; do
      [ "$id" = "id" ] && continue
      case "$st" in
        open|aberto) printf 'specs: GATE FAIL — %s (%s) em aberto: "aberto"\n' "$fid/$id" "$tipo"; failed=1 ;;
      esac
    done < "$fdir/assumptions.reg"
  done

  if [ "$failed" -eq 0 ]; then
    printf '#verdict\tgate\tPASS\n'
  else
    printf '#verdict\tgate\tFAIL\n'
  fi
  return $failed
}

# A3 — nenhuma janela (worktree) viva restante para as features do gate.
specs_gate_orphan_check() {
  local failed=0
  local wt
  wt="$(git -C "$PROJECT_ROOT" worktree list 2>/dev/null)" || return 0
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "$line" in
      *"$PROJECT_ROOT/$SPECS_TREES_DIR"*)
        printf 'specs: GATE FAIL — worktree órfão ainda vivo: %s\n' "$line"
        failed=1 ;;
    esac
  done <<< "$wt"
  return $failed
}

# -------------------------------------------------------- spec constitution

specs_cmd_constitution() {
  specs_require_project || return 1
  local sub="${1:-scan}"
  local file="$PROJECT_ROOT/$SPECS_SPEC_DIR/constitution.md"
  [ -f "$file" ] || { specs_err "sem constitution.md em $PROJECT_ROOT/.spec"; return 1; }

  case "$sub" in
    scan|check)
      local rv=0 line cur_rule="(regra sem título)"
      while IFS= read -r line; do
        case "$line" in
          "## "*)
            cur_rule="${line#\#\# }"
            ;;
          "- scan:"*|'`scan:'*|"scan:"*)
            local cmd
            cmd="$(printf '%s' "$line" | sed -n 's/^[[:space:]]*\(-\?[[:space:]]*\)`*scan:[[:space:]]*//; s/`*[[:space:]]*$//p')"
            [ -n "$cmd" ] || continue
            local out rc
            out="$(cd "$PROJECT_ROOT" && bash -c "$cmd" 2>&1)"
            rc=$?
            if [ "$rc" -eq 127 ]; then
              printf '#regra\t%s\n' "$cur_rule"
              printf 'NAO-VERIFICADO: o comando do scan não existe no ambiente.\n'
              rv=1
            elif [ -n "$out" ]; then
              printf '#regra\t%s\n' "$cur_rule"
              printf '%s\n' "$out"
              rv=1
            fi
            ;;
        esac
      done < "$file"
      if [ "$rv" -eq 0 ]; then
        printf 'specs: constituição respeitada (exit 0)\n'
      else
        printf 'specs: constituição VIOLADA (exit 1)\n'
      fi
      return "$rv"
      ;;
    *)
      printf 'specs: subcomando constitution desconhecido: %s (use scan)\n' "$sub"
      return 1
      ;;
  esac
}

# -------------------------------------------------------- spec lesson

# B5 — gera o próximo id para um prefixo em escopo de feature (U/AC/A/Q)
specs_next_id() {
  local fdir="$1" prefix="$2"
  local max=0 n idfile
  for idfile in "$fdir"/criteria.reg "$fdir"/assumptions.reg "$fdir"/spec.md; do
    [ -f "$idfile" ] || continue
    n="$(grep -oE "\b${prefix}-[0-9]+" "$idfile" 2>/dev/null | sed -n 's/.*-\([0-9]\+\)/\1/p' | sort -n | tail -n1)"
    [ -n "$n" ] && [ "$n" -gt "$max" ] && max="$n"
  done
  printf '%s-%03d' "$prefix" $((max+1))
}

# próximo id L-#### em lessons.md (escopo projeto)
specs_next_lesson_id() {
  local lessons="$PROJECT_ROOT/$SPECS_SPEC_DIR/lessons.md"
  local max=0 n
  if [ -f "$lessons" ]; then
    n="$(grep -oE '\bL-[0-9]+' "$lessons" 2>/dev/null | sed -n 's/L-//p' | sort -n | tail -n1)"
    [ -n "$n" ] && max="$n"
  fi
  printf 'L-%04d' $((max+1))
}

specs_cmd_lesson() {
  local sub="${1:-}"
  case "$sub" in
    add)
      shift || true
      specs_cmd_lesson_add "$@"
      return $?
      ;;
    *)
      specs_cmd_lesson_check "$@"
      return $?
      ;;
  esac
}

# valida âncora e ANEXA com id L-#### numerado automaticamente (B5)
specs_cmd_lesson_add() {
  specs_require_project || return 1
  local file="${1:-}"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    specs_err "use: specs lesson add <arquivo.md>"
    return 2
  fi
  # validação de âncora (mesmo critério do check)
  if ! specs_lesson_validate "$file" >/dev/null 2>&1; then
    specs_err "lição recusada — sem âncora em falha real (ver critérios do check)."
    return 2
  fi
  local lessons="$PROJECT_ROOT/$SPECS_SPEC_DIR/lessons.md"
  mkdir -p "$(dirname "$lessons")"
  [ -f "$lessons" ] || printf '# Lições aprendidas (com lastro)\n\n' > "$lessons"
  local lid; lid="$(specs_next_lesson_id)"

  # grava um bloco no lessons.md sob lock (append via mkdir atômico)
  with_lock "lessons" bash -c '
    set -u
    lessons="$1" lid="$2" src="$3"
    {
      printf "\n## %s\n" "$lid"
      sed "s/^## L-.*/## $lid/; /^## L-####/d" "$src"
    } >> "$lessons"
  ' _ "$lessons" "$lid" "$file"
  local rv=$?
  if [ "$rv" -eq 0 ]; then
    printf 'specs: lição %s anexada em .spec/lessons.md (exit 0)\n' "$lid"
  fi
  return "$rv"
}

specs_cmd_lesson_check() {
  local file="${1:-}"
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    specs_err "use: specs lesson <arquivo.md>"
    return 2
  fi
  specs_lesson_validate "$file"
}

specs_lesson_validate() {
  local file="$1"

  # âncora: linha no formato "Ancora: <caminho> — <texto com AC- e F->"
  local anchor
  anchor="$(grep -E '^\s*-+\s*Ancora:\s+.+' "$file" || true)"
  if [ -z "$anchor" ]; then
    specs_err "lição sem âncora. Deve haver linha: '- Ancora: <algo>'"
    return 2
  fi
  # a âncora precisa citar um critério (AC-) e/ou feature (F-) e fracasso
  if ! printf '%s' "$anchor" | grep -qE '(AC-[0-9]+|F-[0-9]+)'; then
    specs_err "lição inalterável: âncora não cita AC-/F- (lastro em falha real)."
    return 2
  fi
  if ! printf '%s' "$anchor" | grep -qiE '(fail|falhou|erro|error)'; then
    specs_err "lição inalterável: âncora não descreve o fracasso concreto (fail/erro)."
    return 2
  fi
  printf 'specs: lição ancorada aceita (exit 0)\n'
  return 0
}