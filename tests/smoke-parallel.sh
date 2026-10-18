#!/usr/bin/env bash
# smoke-parallel.sh — prova os refinamentos R1 (conflito/dry-merge) e
# R2 (atômica de escrita concorrente) e R3 (status parseável).
set -uo pipefail

SPECS_BIN="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../bin" && pwd)/specs"

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
cd "$TMP"

fail() { echo "PARALLEL FAIL: $1" >&2; exit 1; }
ok()   { echo "  ok: $1"; }

git init -q . || fail "git init"
git config user.email p@t
git config user.name p
git commit --allow-empty -qm init

"$SPECS_BIN" init >/dev/null || fail "init"
"$SPECS_BIN" new "Inscrição" >/dev/null || fail "new"
FD="$(ls -d .spec/features/F-001-*)"; FD="${FD#./}"
FID="$(basename "$FD")"

# 2 tarefas disjuntas
cat > "$FD/tasks/T-001.md" <<'EOF'
# T-001 — validação de CPF
- **ACs:** AC-001
- **Deps:**
- **Files:**
- lib/cpf.ts
- **Run:** grep -q CPF lib/cpf.ts
EOF
cat > "$FD/tasks/T-002.md" <<'EOF'
# T-002 — validação de matrícula
- **ACs:** AC-002
- **Deps:** T-001
- **Files:**
- lib/matricula.ts
- **Run:** grep -q MAT lib/matricula.ts
EOF
printf 'AC-001\tU-001\tCPF valido\tT-001\nAC-002\tU-001\tMatricula valida\tT-002\n' > "$FD/criteria.reg"

echo "== plan-check com 2 janelas disjuntas =="
"$SPECS_BIN" plan-check F-001 >/dev/null 2>&1 || fail "plan-check"
ok "plan-check"

echo "== R2: escrita concorrente em trace.tsv (30 prove em paralelo sem lock) =="
# registra AC-003..AC-032 para poder prová-los
for i in $(seq 3 32); do printf 'AC-%d\tU-001\tteste %d\tT-001\n' "$i" "$i" >> "$FD/criteria.reg"; done
# 30 processos escrevendo ACs diferentes simultaneamente -> todas devem existir
for i in $(seq 3 32); do
  "$SPECS_BIN" prove F-001 "AC-$i" "true" "T-001" >/dev/null 2>&1 &
done
wait
N="$(awk -F'\t' '$1 ~ /^AC-[0-9]+$/' "$FD/trace.tsv" | wc -l)"
[ "$N" -eq 30 ] || fail "esperava 30 linhas de AC em trace.tsv, tem $N"
ok "write concorrente atômica (30 linhas AC)"

echo "== R3: status TSV parseável =="
ST="$( "$SPECS_BIN" status F-001 )"
printf '%s\n' "$ST" | awk -F'\t' '$1=="T"{sq++; saw[$2]=1} $1=="AC"{sq++} END{exit (sq<2)}' && ok "status TSV com linhas T/AC" \
  || fail "status sem formato esperado"

echo "== execução sequencial (T-001, depois T-002 pois T-002 Deps T-001) =="
"$SPECS_BIN" track F-001 T-001 >/dev/null 2>&1 || fail "track T-001"
T1="$PWD/.spec/trees/$FID/T-001"
mkdir -p "$T1/lib" && printf '# CPF\n' > "$T1/lib/cpf.ts"
git -C "$T1" add -A && git -C "$T1" commit -qm "T-001: cpf"
"$SPECS_BIN" state F-001 T-001 done >/dev/null || fail "state T-001 done"

"$SPECS_BIN" track F-001 T-002 >/dev/null 2>&1 || fail "track T-002"
T2="$PWD/.spec/trees/$FID/T-002"
mkdir -p "$T2/lib" && printf '# MAT\n' > "$T2/lib/matricula.ts"
git -C "$T2" add -A && git -C "$T2" commit -qm "T-002: matricula"
"$SPECS_BIN" state F-001 T-002 done >/dev/null || fail "state T-002 done"

echo "== integrate T-002 ANTES de T-001 deve RAZÃO (deps) =="
"$SPECS_BIN" integrate F-001 T-002 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "integrate T-002 antes do T-001 deveria falhar (deps)"
ok "integrate respeitou dep"

"$SPECS_BIN" integrate F-001 T-001 >/dev/null 2>&1 || fail "integrate T-001"
"$SPECS_BIN" integrate F-001 T-002 >/dev/null 2>&1 || fail "integrate T-002"
ok "integrate em ordem"

echo "== R1: conflito real de merge (mesmo arquivo, linhas diferentes) =="
cat > "$FD/tasks/T-003.md" <<'EOF'
# T-003 — geração de relatório
- **ACs:** AC-003
- **Deps:**
- **Files:**
- lib/cpf.ts
- **Run:** true
EOF
printf 'AC-003\tU-001\tRelatorio\tT-003\n' >> "$FD/criteria.reg"
"$SPECS_BIN" track F-001 T-003 >/dev/null 2>&1 || fail "track T-003"
T3="$PWD/.spec/trees/$FID/T-003"
printf 'linha do T-003\n' > "$T3/lib/cpf_extra.txt"
# conflito planejado: main editou cpf.ts, janela também
printf '# CPF v2 main\n' > lib/cpf.ts && git add -A && git commit -qm "main: cpf v2"
printf '# CPF v3 janela\n' > "$T3/lib/cpf.ts"
git -C "$T3" add -A && git -C "$T3" commit -qm "T-003: cpf v3"
"$SPECS_BIN" state F-001 T-003 done >/dev/null
"$SPECS_BIN" integrate F-001 T-003 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "integrate T-003 com conflito deveria falhar (rc=$rc)"
git -C "$PWD" merge --abort >/dev/null 2>&1 || true
ok "conflito detectado e abortado (janela preservada)"

echo == reexecução com janela limpa ==
"$SPECS_BIN" track F-001 T-003 --clean >/dev/null 2>&1 || fail "track T-003 --clean"
T3="$PWD/.spec/trees/$FID/T-003"
[ -d "$T3" ] || fail "janela limpa não recriada"
# a janela re-executa a tarefa do zero contra o main atualizado (cpf v2 main)
printf 'relatorio\n' > "$T3/lib/cpf.ts"
git -C "$T3" add -A && git -C "$T3" commit -qm "T-003: reexecutado"
"$SPECS_BIN" state F-001 T-003 done >/dev/null
"$SPECS_BIN" integrate F-001 T-003 >/dev/null 2>&1 || fail "integrate após reexecução"
ok "redexecução + integração limpa"

echo
echo "PARALLEL SMOKE PASS"