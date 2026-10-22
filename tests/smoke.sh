#!/usr/bin/env bash
# smoke.sh — prova o pipeline TDD sequencial (spec → tests → implement → docs
# → review → commit único gated) num repositório git temporário.
set -uo pipefail

SPECS_BIN="${SPECS_BIN:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../bin" && pwd)/specs}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() { echo "SMOKE FAIL: $1" >&2; exit 1; }
step_ok() { echo "  ok: $1"; }

git init -q . || fail "git init"
git config user.email smoke@test
git config user.name smoke
git commit --allow-empty -qm init

echo "== init =="
"$SPECS_BIN" init >/dev/null || fail "init"
[ -f .spec/constitution.md ] || fail "constitution nao criado"
step_ok "init"

echo "== spec-open (1 worktree por spec) =="
"$SPECS_BIN" spec-open "Inscrição de alunos" >/dev/null || fail "spec-open"
FD="$(ls -d .spec/features/F-001-*)"; FD="${FD#./}"
FID="$(basename "$FD")"
[ -f "$FD/phase.tsv" ] || fail "phase.tsv nao criado"
[ -f "$FD/reviews.reg" ] || fail "reviews.reg nao criado"
TREE=".spec/trees/$FID"
[ -d "$TREE" ] || fail "worktree da spec nao criada ($TREE)"
# exatamente 1 worktree extra (a da spec), não uma por tarefa
NWT="$(git worktree list | wc -l)"
[ "$NWT" -eq 2 ] || fail "esperava 2 worktrees (main + spec), tem $NWT"
step_ok "spec-open: worktree única ($NWT worktrees)"

echo "== F0 spec gate (deve falhar: criteria vazio) =="
"$SPECS_BIN" gate F-001 spec >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate spec deveria falhar com criteria vazio"
step_ok "gate spec rejeita criteria vazio"

echo "== preenche spec (F0 ok) =="
cat > "$FD/spec.md" <<EOF
# $FID — Inscrição de alunos

## Histórias
- U-001 — Como secretária, quero cadastrar inscrição com CPF, para registrar entrada.

## Critérios
- AC-001 — [U-001]
- AC-002 — [U-001]
EOF
printf 'AC-001\tU-001\tCPF valido aceito\tT-SPEC\nAC-002\tU-001\tCPF invalido recusado\tT-SPEC\n' > "$FD/criteria.reg"
printf 'A-001\tA\tconfirmed\tAmbiente autenticado\n' > "$FD/assumptions.reg"
"$SPECS_BIN" gate F-001 spec >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate spec rc=$rc"
step_ok "F0 spec PASS"

echo "== F1 tests (TDD: testes antes; sem teste -> falha) =="
"$SPECS_BIN" gate F-001 tests >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate tests deveria falhar sem teste registrado"
# escreve os testes ANTES do código, na worktree da spec
mkdir -p "$TREE/src"
cat > "$TREE/src/cpf.test.js" <<'EOF'
const { validarCpf } = require('./cpf.js');
let pass=0, fail=0;
function assert(c,n){ if(c) pass++; else { fail++; console.error('FAIL '+n); } }
assert(validarCpf('12345678909')===true, 'AC-001');
assert(validarCpf('000')===false, 'AC-002');
if(fail){ process.exit(1); }
console.log('OK '+pass);
EOF
"$SPECS_BIN" prove F-001 AC-001 "node -e \"require('./src/cpf.test.js')\"" T-SPEC >/dev/null 2>&1 || fail "prove AC-001"
"$SPECS_BIN" prove F-001 AC-002 "node -e \"require('./src/cpf.test.js')\"" T-SPEC >/dev/null 2>&1 || fail "prove AC-002"
"$SPECS_BIN" gate F-001 tests >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate tests rc=$rc"
step_ok "F1 tests PASS (testes antes do código)"

echo "== F2 implement (TDD: rojo antes, verde depois) =="
"$SPECS_BIN" gate F-001 implement >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate implement deveria falhar sem implementação (test rojo)"
cat > "$TREE/src/cpf.js" <<'EOF'
function validarCpf(c){ if(!c || c.length!==11) return false; return true; }
module.exports={validarCpf};
EOF
"$SPECS_BIN" gate F-001 implement >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate implement rc=$rc"
step_ok "F2 implement PASS (rojo -> verde)"

echo "== F3 docs =="
"$SPECS_BIN" gate F-001 docs >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate docs deveria falhar sem docs"
mkdir -p docs/features
cat > "docs/features/$FID.md" <<EOF
# $FID — Inscrição de alunos

TDD implementado:
- AC-001: CPF válido aceito.
- AC-002: CPF inválido recusado.
EOF
"$SPECS_BIN" gate F-001 docs >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate docs rc=$rc"
step_ok "F3 docs PASS"

echo "== F4 review (deep obrigatório + constituição) =="
"$SPECS_BIN" gate F-001 review >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate review deveria falhar sem deep review"
"$SPECS_BIN" review F-001 T-SPEC --deep=approved >/dev/null 2>&1 || fail "deep approved"
"$SPECS_BIN" gate F-001 review >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate review rc=$rc (constituição no preset ajustado)"
step_ok "F4 review PASS"

echo "== F5 commit (gated: sem aprovação não commita) =="
# antes da aprovação: git log segue limpo
"$SPECS_BIN" commit F-001 >/dev/null 2>&1 || true
NCOMMITS_BEFORE="$(git rev-list --count HEAD)"
[ "$NCOMMITS_BEFORE" -eq 1 ] || fail "nada deveria ter sido commitado antes da aprovação (commits=$NCOMMITS_BEFORE)"
# commit --approve sem T-SPEC approved -> falha
"$SPECS_BIN" commit F-001 --approve >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "commit --approve sem aprovação T-SPEC deveria falhar"
# aprova e commita
"$SPECS_BIN" review F-001 T-SPEC --approve >/dev/null 2>&1 || fail "approve T-SPEC"
"$SPECS_BIN" commit F-001 --approve >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "commit --approve rc=$rc"
NCOMMITS_AFTER="$(git rev-list --count HEAD)"
[ "$NCOMMITS_AFTER" -eq 2 ] || fail "esperava exatamente 1 commit final (commits=$NCOMMITS_AFTER)"
# worktree da spec removida após merge
[ -d "$TREE" ] && fail "worktree da spec deveria ter sido removida"
NWT="$(git worktree list | wc -l)"
[ "$NWT" -eq 1 ] || fail "esperava 1 worktree (main), tem $NWT"
step_ok "F5 commit único gated + merge + worktree limpa"

echo "== gate recusa pular fases (nova spec) =="
"$SPECS_BIN" spec-open "Outra feature" >/dev/null 2>&1 || fail "spec-open 2"
# tenta pular direto para implement -> deve falhar (spec/tests pendentes)
"$SPECS_BIN" gate F-002 implement >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate implement em spec nova deveria falhar (ordem forçada)"
step_ok "ordem forçada (não pula fase)"

echo "== constitution scan (limpa + violação) =="
"$SPECS_BIN" constitution scan >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "constitution limpa rc=$rc"
mkdir -p src
printf 'logger.info("cpf do aluno: %%s", cpf)\n' > src/bad.js
"$SPECS_BIN" constitution scan >/dev/null 2>&1; rc=$?
[ "$rc" -eq 1 ] || fail "constitution com violação deveria falhar (rc=$rc)"
rm -f src/bad.js
step_ok "constitution limpa (0) + violação (1)"

echo "== lesson (sem âncora recusada; com âncora aceita) =="
cat > une.md <<'EOF'
## L-001 — aprendi
- Lição: sempre testar.
EOF
"$SPECS_BIN" lesson une.md >/dev/null 2>&1; rc=$?
[ "$rc" -eq 2 ] || fail "lesson sem ancora deveria exit 2 (rc=$rc)"
cat > anc.md <<'EOF'
## L-001 — aprendi
- Ancora: critério AC-001 da F-001 falhou com node: arquivo ausente (fail)
- Lição: garantir fixture antes do teste.
EOF
"$SPECS_BIN" lesson add anc.md >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "lesson add ancorada deveria exit 0 (rc=$rc)"
grep -q "L-0001" .spec/lessons.md || fail "lesson add não anexou L-0001"
step_ok "lesson com lastro (recusa sem âncora, anexa com L-0001)"

echo
echo "SMOKE PASS"