#!/usr/bin/env bash
set -euo pipefail

# Install AI CLIs (via npm) after Node is available through mise
# Packages:
# - @openai/codex (bin: codex)
# - @google/gemini-cli (bin: gemini)
#
# NOTE: Claude Code is installed via native installer (not npm)
# See: install/apps/claude-code.sh

if ! command -v npm >/dev/null 2>&1; then
  echo "[ezdora][ai-cli] npm não encontrado. Garanta Node via mise (bash install/apps/mise-setup.sh) e reabra o shell." >&2
  exit 0
fi

# Configure npm to use user directory for global packages (idempotent)
NPM_PREFIX="$HOME/.npm-global"
CURRENT_PREFIX=$(npm config get prefix 2>/dev/null || echo "")

if [ "$CURRENT_PREFIX" != "$NPM_PREFIX" ]; then
  echo "[ezdora][ai-cli] Configurando npm para usar diretório do usuário..."
  mkdir -p "$NPM_PREFIX"
  npm config set prefix "$NPM_PREFIX"

  # Add to PATH in current shell
  export PATH="$NPM_PREFIX/bin:$PATH"

  # Add to shell configs if not present
  for RC_FILE in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC_FILE" ]; then
      if ! grep -q "export PATH=.*\.npm-global/bin" "$RC_FILE"; then
        echo "" >> "$RC_FILE"
        echo "# npm global packages" >> "$RC_FILE"
        echo "export PATH=\"\$HOME/.npm-global/bin:\$PATH\"" >> "$RC_FILE"
      fi
    fi
  done

  echo "[ezdora][ai-cli] npm configurado para usar: $NPM_PREFIX"
fi

# Map packages to expected bin names for idempotency checks
# NOTE: claude-code removed - use native installer instead
PKGS=("@openai/codex" "@google/gemini-cli")
BINS=("codex" "gemini")

MISSING_PKGS=()
for i in "${!PKGS[@]}"; do
  bin="${BINS[$i]}"
  if ! command -v "$bin" >/dev/null 2>&1; then
    MISSING_PKGS+=("${PKGS[$i]}")
  fi
done

if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
  echo "[ezdora][ai-cli] CLIs já instaladas (codex/gemini). Pulando."
  exit 0
fi

echo "[ezdora][ai-cli] Instalando via npm: ${MISSING_PKGS[*]}"
npm install -g "${MISSING_PKGS[@]}" || {
  echo "[ezdora][ai-cli] Falha na instalação via npm. Verifique conexão/permissões." >&2
  exit 1
}

echo "[ezdora][ai-cli] Concluído. Configure variáveis: OPENAI_API_KEY, GOOGLE_API_KEY."
echo "[ezdora][ai-cli] Para Claude Code, use: bash install/apps/claude-code.sh"
