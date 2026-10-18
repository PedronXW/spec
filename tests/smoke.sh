#!/usr/bin/env bash
# smoke.sh — prova o ciclo spec-anchored num repositório git temporário.
# Cobre: init, new, plan-check, track, prove (awaiting lock), integrate,
# proof, gate, resolve, constitution, lesson. O veredito é o exit code.
set -uo pipefail

SPECS_BIN="${SPECS_BIN:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../bin" && pwd)/specs}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() { echo "SMOKE FAIL: $1" >&2; exit 1; }
step_ok() { echo "  ok: $1"; }

git init -q .
git config user.email smoke@test
git config user.name smoke
git commit --allow-empty -qm init

echo "== init =="
"$SPECS_BIN" init >/dev/null || fail "init"
[ -f .spec/constitution.md ] || fail "constitution nao criado"
[ -f .spec/features/README.md ] || fail "features README"
step_ok "init"

echo "== new =="
"$SPECS_BIN" new "Inscrição de alunos" >/dev/null || fail "new"
FD="$(ls -d .spec/features/F-001-*)"
FD="${FD#./}"
FID="$(basename "$FD")"
[ -n "$FD" ] || fail "feature nao criada"
[ -f "$FD/criteria.reg" ] && [ -f "$FD/trace.tsv" ] || fail "arquivos mecanicos ausentes"
step_ok "new: $FD"

echo "== plan-check (pré-plano vazio deve passar: só aviso de AC sem prova) =="
"$SPECS_BIN" plan-check . >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "plan-check rc=$rc"
step_ok "plan-check"

echo "== escreve plano + critérios =="
cat > "$FD/tasks/T-001.md" <<'EOF'
# T-001 — validação de CPF
- **ACs:** AC-001
- **Deps:**
- **Files:**
- lib/cpf.ts
- **Run:** grep -q 'CPF' lib/cpf.ts
EOF
printf 'AC-001\tU-001\tCPF valido aceito\tT-001\n' > "$FD/criteria.reg"
printf 'A-001\tA\taberto\tAmbiente autenticado\n' > "$FD/assumptions.reg"
# spec.md consistente (sem drift): só AC-001
cat > "$FD/spec.md" <<'EOF'
# F-001 — Inscrição de alunos

## Histórias de usuário
- U-001 — Como secretária, quero cadastrar inscrição, para registrar entrada.

## Critérios de aceite
- AC-001 — [U-001]

## Suposições
- A-001 — Ambiente autenticado. — aberto
EOF
step_ok "plano/criteria/spec escritos"

echo "== plan-check com dado real =="
"$SPECS_BIN" plan-check . >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "plan-check real rc=$rc"
step_ok "plan-check"

echo "== track (worktree) =="
"$SPECS_BIN" track F-001 T-001 >/dev/null 2>&1 || fail "track"
TREE=".spec/trees/$FID/T-001"
[ -d "$TREE" ] || fail "worktree nao criado ($TREE)"
git worktree list >/dev/null 2>&1 && git worktree list | grep -q "$TREE" && rc=0 || rc=1
[ "$rc" -eq 0 ] || fail "worktree ausente no git worktree list"
step_ok "track: $TREE"
STATUS="$("$SPECS_BIN" status F-001 2>&1)"
case "$STATUS" in *"T-001"*"running"*) : ;; *) fail "status nao mostra running: $STATUS" ;; esac
step_ok "status mostra running"

echo "== executa a janela (um commit) =="
mkdir -p "$TREE/lib"
printf '# CPF validator\n' > "$TREE/lib/cpf.ts"
git -C "$TREE" add -A && git -C "$TREE" commit -qm "T-001: validação de CPF"
step_ok "commit T-001 na janela"
"$SPECS_BIN" state F-001 T-001 done >/dev/null || fail "state done"
step_ok "state done"

echo "== prove =="
"$SPECS_BIN" prove F-001 AC-001 "grep -q 'CPF' lib/cpf.ts" T-001 >/dev/null || fail "prove"
[ "$(grep -c 'AC-001' "$FD/trace.tsv")" -eq 1 ] || fail "trace.tsv deve ter 1 linha AC-001"
step_ok "prove regitrou 1 linha (upsert via lock)"

echo "== integrate =="
"$SPECS_BIN" integrate F-001 T-001 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "integrate rc=$rc"
[ -d "$TREE" ] && fail "worktree deveria ter sido removido"
STATUS="$( "$SPECS_BIN" status F-001 2>&1 )"
case "$STATUS" in *"T-001"*"integrated"*) : ;; *) fail "status nao mostra integrated: $STATUS" ;; esac
step_ok "integrate + worktree removido + status integrated"

echo "== proof no estado integrado =="
"$SPECS_BIN" proof F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "proof rc=$rc (esperado 0)"
step_ok "proof PASS (exit 0)"

echo "== gate com A- aberta deve FALHAR =="
"$SPECS_BIN" gate F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate deveria falhar com A-002/A-001 aberta (rc=$rc)"
step_ok "gate rejeitou A- aberta"

echo "== resolve A-001 =="
"$SPECS_BIN" resolve F-001 A-001 confirmed >/dev/null || fail "resolve"
"$SPECS_BIN" gate F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate deveria passar após resolver (rc=$rc, saida: $?)"
step_ok "gate PASS após resolver"

echo "== constitution scan =="
"$SPECS_BIN" constitution scan >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "constitution limpo deveria passar (rc=$rc)"
step_ok "constitution limpa (exit 0)"
# violação real deve falhar
mkdir -p src
printf 'logger.info("cpf do aluno: %%s", cpf)\n' > src/bad.js
"$SPECS_BIN" constitution scan >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] || fail "constitution com violação deveria falhar (rc=$rc)"
rm -f src/bad.js
step_ok "constitution detectou violação (exit 1)"

echo "== lesson (sem âncora → recusar) =="
cat > une.md <<'EOF'
## L-001 — aprendi uma coisa
- Lição: sempre testar.
EOF
"$SPECS_BIN" lesson une.md >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] || fail "lesson sem ancora deveria exit 2 (rc=$rc)"
step_ok "lesson sem ancora recusada (exit 2)"

cat > anc.md <<'EOF'
## L-001 — aprendi uma coisa
- Ancora: critério AC-001 da F-001 falhou com grep -q 'CPF': arquivo ausente (fail)
- Lição: garantir fixture antes do teste.
EOF
"$SPECS_BIN" lesson anc.md >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "lesson ancorada deveria exit 0 (rc=$rc)"
step_ok "lesson ancorada aceita (exit 0)"

echo "== lesson add (anexa com L-#### automático) =="
"$SPECS_BIN" lesson add anc.md >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "lesson add deveria exit 0 (rc=$rc)"
grep -q "L-0001" .spec/lessons.md || fail "lesson add não anexou com id L-0001"
step_ok "lesson add anexou com L-0001"

echo "== reconcile (drift spec.md <-> criteria.reg) =="
# spec.md atual só tem AC-001 e criteria.reg tem AC-001 -> sem drift
"$SPECS_BIN" reconcile F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "reconcile consistente deveria passar (rc=$rc)"
# introduz drift: mentiona AC-999 na spec
printf '\n- AC-999 — [U-001]\n' >> "$FD/spec.md"
"$SPECS_BIN" reconcile F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "reconcile com drift deveria falhar (rc=$rc)"
# remove o drift
sed -i '/AC-999/d' "$FD/spec.md"
step_ok "reconcile detecta drift e recupera"

echo "== gate rejeita worktree órfão (A3) =="
# cria worktree órfão manualmente (janela não integrada)
git worktree add -b spec/F-001-inscri-o-de-alunos/T-ORPHAN .spec/trees/F-001-inscri-o-de-alunos/T-ORPHAN HEAD >/dev/null 2>&1 || fail "criar worktree órfão"
"$SPECS_BIN" gate F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate deveria rejeitar worktree órfão (rc=$rc)"
git worktree remove --force .spec/trees/F-001-inscri-o-de-alunos/T-ORPHAN >/dev/null 2>&1 || true
git branch -D spec/F-001-inscri-o-de-alunos/T-ORPHAN >/dev/null 2>&1 || true
step_ok "gate rejeita worktree órfão"

echo "== proof --strict rejeita teste pulado (A2) =="
# comando que retorna 0 mas é um skip (vitest/describe.skip)
"$SPECS_BIN" prove F-001 AC-001 "echo 'SKIP: it.skip cpf' && exit 0" T-001 >/dev/null 2>&1 || fail "prove"
"$SPECS_BIN" proof F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "proof normal deveria passar (rc=$rc)"
"$SPECS_BIN" proof --strict F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "proof --strict deveria falhar com skip (rc=$rc)"
# restaura prova real
"$SPECS_BIN" prove F-001 AC-001 "grep -q 'CPF' lib/cpf.ts" T-001 >/dev/null 2>&1 || fail "prove restore"
step_ok "proof --strict detecta teste pulado"

echo "== gate rejeita constituição violada (A1) =="
mkdir -p src
printf 'logger.info("cpf do aluno: %%s", cpf)\n' > src/bad.js
"$SPECS_BIN" gate F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate deveria rejeitar constituição violada (rc=$rc)"
rm -f src/bad.js
"$SPECS_BIN" gate F-001 >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate deveria passar após remover violação (rc=$rc)"
step_ok "gate rejeita constituição violada"

echo
echo "SMOKE PASS"