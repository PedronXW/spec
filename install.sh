#!/usr/bin/env bash
# Instala a skill spec-anchored + CLI `specs` globalmente.
#
# CLI:  ~/.local/bin/specs  (else /usr/local/bin)
# Skill:~/.config/opencode/skills/specs/
# cmds: ~/.config/opencode/command/specs*.md
set -euo pipefail

SRC="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# lint antes de instalar — falha aborta a instalação
echo "lint: bash -n …"
bash -n "$SRC/bin/specs" "$SRC/lib/specs.sh" "$SRC/lib/commands.sh" || {
  echo "✗ lint falhou — instalação abortada." >&2
  exit 1
}
echo "✓ lint OK"

BIN_DIR="${SPECS_BIN_DIR:-$HOME/.local/bin}"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

mkdir -p "$BIN_DIR" "$CONF_DIR/skills" "$CONF_DIR/command"

ln -sfn "$SRC/bin/specs" "$BIN_DIR/specs"
ln -sfn "$SRC/skill/specs" "$CONF_DIR/skills/specs"
for c in "$SRC"/commands/specs-*.md; do
  [ -e "$c" ] || continue
  ln -sfn "$c" "$CONF_DIR/command/$(basename "$c")"
done
ln -sfn "$SRC/commands/specs.md" "$CONF_DIR/command/specs.md"

echo "✓ CLI  -> $BIN_DIR/specs"
echo "✓ skill-> $CONF_DIR/skills/specs"
echo "✓ cmds -> $CONF_DIR/command/specs*.md"

# permission: gate de revisão (nenhum commit/merge/push sem ask)
apply_permission() {
  local cfg="$1"
  [ -f "$cfg" ] || { echo "  (sem $cfg — config não localizada)" >&2; return 1; }
  if grep -q '"permission"' "$cfg"; then
    echo "✓ permission já presente em $cfg"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$cfg" <<'PY'
import json, sys
p = sys.argv[1]
try:
    data = json.load(open(p))
except Exception:
    # jsonc — tenta sem comentários simples
    txt = open(p).read()
    data = json.loads(txt.replace('//','').replace(',}','}').replace(',]',']'))
data['permission'] = {
    "bash": {
        "*git*commit*": "ask",
        "*git*merge*": "ask",
        "*git*push*": "ask",
        "*specs*integrate*": "ask"
    }
}
open(p,'w').write(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
    echo "✓ permission (git commit/merge/push/integrate -> ask) gravado em $cfg"
    return 0
  fi
  echo "⚠  não consegui editar $cfg automaticamente (python3 ausente)." >&2
  echo "   Adicione manualmente o bloco 'permission' (veja README → Revisão em 3 camadas)." >&2
  return 1
}

CFG_GLOBAL="${CONF_DIR}/opencode.json"
CFG_GLOBALC="${CONF_DIR}/opencode.jsonc"
if [ -f "$CFG_GLOBAL" ]; then
  apply_permission "$CFG_GLOBAL"
elif [ -f "$CFG_GLOBALC" ]; then
  apply_permission "$CFG_GLOBALC"
else
  apply_permission "$CFG_GLOBALC"
fi

# PATH check
if ! command -v specs >/dev/null 2>&1; then
  echo
  echo "⚠  '$BIN_DIR' não está no seu PATH. Adicione, ex.:"
  echo "   echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
fi

echo
echo "Reinicie o opencode para carregar skill, comandos e permission."