#!/usr/bin/env bash
# smoke-custom-id.sh — prova o identificador customizado (--id): criação,
# validação, colisão, resolução e pipeline TDD completo num repo git temporário.
# O auto F-### deve continuar funcionando e não interferir com ids custom.
set -uo pipefail

SPECS_BIN="${SPECS_BIN:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../bin" && pwd)/specs}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

fail() { echo "SMOKE-CUSTOM FAIL: $1" >&2; exit 1; }
step_ok() { echo "  ok: $1"; }

git init -q . || fail "git init"
git config user.email smoke@test
git config user.name smoke
git commit --allow-empty -qm init

echo "== init =="
"$SPECS_BIN" init >/dev/null || fail "init"
step_ok "init"

echo "== spec-open com --id customizado =="
"$SPECS_BIN" spec-open "Login SSO" --id AUTH-1142 >/dev/null 2>&1 || fail "spec-open --id"
FID="AUTH-1142-login-sso"
[ -d ".spec/features/$FID" ] || fail "dir custom não criado (.spec/features/$FID)"
[ -f ".spec/features/$FID/phase.tsv" ] || fail "phase.tsv não criado"
TREE=".spec/trees/$FID"
[ -d "$TREE" ] || fail "worktree da spec não criada ($TREE)"
git rev-parse --verify --quiet "spec/$FID" >/dev/null || fail "branch spec/$FID não criada"
step_ok "dir+worktree+branch: $FID"

echo "== status resolve pelo id customizado =="
out="$("$SPECS_BIN" status AUTH-1142)"
printf '%s\n' "$out" | grep -Fq "AUTH-1142-login-sso" || fail "status não resolve AUTH-1142"
step_ok "resolução por prefixo do id"

echo "== validação do id (inválidos recusados) =="
for bad in "bad id" "F-001" "9abc" "-lead" "trail-"; do
  "$SPECS_BIN" spec-open "X" --id "$bad" >/dev/null 2>&1; rc=$?
  [ "$rc" -ne 0 ] || fail "id '$bad' deveria ser recusado"
done
step_ok "recusa ids inválidos (espaço, F-reservado, dígito inicial, hífens nas pontas)"

echo "== colisão de identificador recusada =="
"$SPECS_BIN" spec-open "Login SSO" --id AUTH-1142 >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "identificador duplicado deveria falhar"
step_ok "duplicata recusada"

echo "== F0 spec gate (id custom) =="
"$SPECS_BIN" gate AUTH-1142 spec >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate spec deveria falhar com criteria vazio"
cat > ".spec/features/$FID/spec.md" <<EOF
# $FID — Login SSO

## Histórias
- U-001 — Como usuário, quero logar com SSO, para acessar sem senha.

## Critérios
- AC-001 — [U-001]
EOF
printf 'AC-001\tU-001\tSSO login ok\tT-SPEC\n' > ".spec/features/$FID/criteria.reg"
printf 'A-001\tA\tconfirmed\tProvedor configurado\n' > ".spec/features/$FID/assumptions.reg"
"$SPECS_BIN" gate AUTH-1142 spec >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate spec rc=$rc"
step_ok "F0 spec PASS"

echo "== F1 tests (TDD, id custom) =="
"$SPECS_BIN" gate AUTH-1142 tests >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate tests deveria falhar sem teste"
mkdir -p "$TREE/src"
cat > "$TREE/src/sso.test.js" <<'EOF'
const { login } = require('./sso.js');
let pass=0, fail=0;
function assert(c,n){ if(c) pass++; else { fail++; console.error('FAIL '+n); } }
assert(login('a@b.c')===true, 'AC-001');
if(fail){ process.exit(1); }
console.log('OK '+pass);
EOF
"$SPECS_BIN" prove AUTH-1142 AC-001 "node -e \"require('./src/sso.test.js')\"" T-SPEC >/dev/null 2>&1 || fail "prove AC-001"
"$SPECS_BIN" gate AUTH-1142 tests >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate tests rc=$rc"
step_ok "F1 tests PASS"

echo "== F2 implement (rojo -> verde, id custom) =="
"$SPECS_BIN" gate AUTH-1142 implement >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate implement deveria falhar sem implementação"
cat > "$TREE/src/sso.js" <<'EOF'
function login(u){ return typeof u === 'string' && u.length > 0; }
module.exports={login};
EOF
"$SPECS_BIN" gate AUTH-1142 implement >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate implement rc=$rc"
step_ok "F2 implement PASS"

echo "== F3 docs (id custom) =="
"$SPECS_BIN" gate AUTH-1142 docs >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate docs deveria falhar sem docs"
mkdir -p docs/features
cat > "docs/features/$FID.md" <<EOF
# $FID — Login SSO

- AC-001: SSO login aceito.
EOF
"$SPECS_BIN" gate AUTH-1142 docs >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate docs rc=$rc"
step_ok "F3 docs PASS"

echo "== F4 review (id custom) =="
"$SPECS_BIN" gate AUTH-1142 review >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "gate review deveria falhar sem deep review"
"$SPECS_BIN" review AUTH-1142 T-SPEC --deep=approved >/dev/null 2>&1 || fail "deep approved"
"$SPECS_BIN" gate AUTH-1142 review >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "gate review rc=$rc"
step_ok "F4 review PASS"

echo "== F5 commit gated (id custom) =="
"$SPECS_BIN" commit AUTH-1142 >/dev/null 2>&1 || true
[ "$(git rev-list --count HEAD)" -eq 1 ] || fail "nada deveria ter sido commitado antes da aprovação"
"$SPECS_BIN" commit AUTH-1142 --approve >/dev/null 2>&1; rc=$?
[ "$rc" -ne 0 ] || fail "commit --approve sem T-SPEC approved deveria falhar"
"$SPECS_BIN" review AUTH-1142 T-SPEC --approve >/dev/null 2>&1 || fail "approve T-SPEC"
"$SPECS_BIN" commit AUTH-1142 --approve >/dev/null 2>&1; rc=$?
[ "$rc" -eq 0 ] || fail "commit --approve rc=$rc"
[ "$(git rev-list --count HEAD)" -eq 2 ] || fail "esperava exatamente 1 commit final"
[ -d "$TREE" ] && fail "worktree da spec deveria ter sido removida"
step_ok "F5 commit único gated + merge + worktree limpa"

echo "== auto F-### segue intacto (não mistura com custom) =="
"$SPECS_BIN" spec-open "Outra feature" >/dev/null 2>&1 || fail "spec-open auto"
[ -d .spec/features/F-001-outra-feature ] || fail "auto F-001 não criado"
step_ok "auto-geração F-001 continua funcionando"

echo "SMOKE-CUSTOM-ID PASS"