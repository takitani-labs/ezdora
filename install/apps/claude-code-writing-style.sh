#!/usr/bin/env bash
set -euo pipefail

# Claude Code writing-style guidance
# Deploys a shared "write so it doesn't read as AI" guide to ~/.claude/writing-style.md
# and wires it into every Claude memory file via an @import, so it loads in every
# session across all profiles. Single source of truth: edit the template, re-run.

MARKER="ezdora:writing-style"
IMPORT_LINE='@~/.claude/writing-style.md'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/../templates/claude/writing-style.md"
SHARED="$HOME/.claude/writing-style.md"

if [ ! -f "$TEMPLATE" ]; then
  echo "[ezdora][writing-style] Template not found: $TEMPLATE. Skipping."
  exit 0
fi

# ezdora owns the shared file: always refresh so content updates propagate.
mkdir -p "$HOME/.claude"
cp "$TEMPLATE" "$SHARED"
echo "[ezdora][writing-style] Deployed shared guide: $SHARED"

# Ensure a CLAUDE.md imports the shared guide (idempotent; safe to re-run).
ensure_import() {
  local md="$1"
  mkdir -p "$(dirname "$md")"

  if [ -f "$md" ] && grep -qF "$MARKER" "$md" 2>/dev/null; then
    echo "[ezdora][writing-style] Already wired: $md"
    return 0
  fi

  # Seed a header only when creating the file from scratch.
  [ -f "$md" ] || printf '# Claude Code instructions\n' > "$md"

  {
    printf '\n<!-- %s (managed by ezdora) -->\n' "$MARKER"
    printf '%s\n' "$IMPORT_LINE"
    printf '<!-- /%s -->\n' "$MARKER"
  } >> "$md"
  echo "[ezdora][writing-style] Wired import into: $md"
}

# Base user-level instructions (loaded when running without a profile).
ensure_import "$HOME/.claude/CLAUDE.md"

# Every existing profile (created by claude-code-profiles.sh / claude-code.sh).
# Only touch profile dirs that already exist: do not pre-create them, since
# claude-code.sh keys its settings.json copy on the profile dir being absent.
if [ -d "$HOME/.claude-profiles" ]; then
  for profile_dir in "$HOME/.claude-profiles"/*/; do
    [ -d "$profile_dir" ] || continue
    ensure_import "${profile_dir}CLAUDE.md"
  done
fi

echo "[ezdora][writing-style] Done."
