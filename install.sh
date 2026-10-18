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

# PATH check
if ! command -v specs >/dev/null 2>&1; then
  echo
  echo "⚠  '$BIN_DIR' não está no seu PATH. Adicione, ex.:"
  echo "   echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
fi

echo
echo "Reinicie o opencode para carregar skill e comandos."