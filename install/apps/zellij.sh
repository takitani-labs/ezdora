#!/usr/bin/env bash
set -euo pipefail

# Install Zellij - a terminal workspace/multiplexer (https://zellij.dev/)
# Opt-in: set EZDORA_INSTALL_ZELLIJ=true to enable
if [ "${EZDORA_INSTALL_ZELLIJ:-false}" != "true" ]; then
  echo "[ezdora][zellij] Skipping (set EZDORA_INSTALL_ZELLIJ=true to install)"
  exit 0
fi

# Source helper functions
source "$(dirname "$0")/../utils/download-helper.sh" 2>/dev/null || {
  echo "[ezdora][zellij] ⚠️  Helper não encontrado, usando modo básico"
}

# Ensure ~/.local/bin is in PATH for current session
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

if command -v zellij >/dev/null 2>&1; then
  echo "[ezdora][zellij] Já instalado. Pulando."
  exit 0
fi

install_zellij() {
  echo "[ezdora][zellij] Instalando..."

  # Tenta via DNF primeiro (não empacotado oficialmente, mas pode existir em copr/overlay)
  if sudo dnf install -y zellij 2>/dev/null; then
    echo "[ezdora][zellij] ✅ Instalado via DNF."
    return 0
  fi

  echo "[ezdora][zellij] Não encontrado no DNF. Usando download do GitHub."

  # Detect architecture
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)        TARGET="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) TARGET="aarch64-unknown-linux-musl" ;;
    *)
      echo "[ezdora][zellij] ⚠️  Arquitetura não suportada: $ARCH"
      return 1
      ;;
  esac

  # Get latest version tag (fallback to a known-good version)
  VERSION=$(curl -s --connect-timeout 10 https://api.github.com/repos/zellij-org/zellij/releases/latest 2>/dev/null \
    | grep '"tag_name"' | sed -E 's/.*"(v[^"]+)".*/\1/' || echo "v0.43.1")
  [ -n "$VERSION" ] || VERSION="v0.43.1"

  URL="https://github.com/zellij-org/zellij/releases/download/${VERSION}/zellij-${TARGET}.tar.gz"
  echo "[ezdora][zellij] Baixando ${VERSION} para ${TARGET}..."

  # Use a dedicated temp dir to avoid collisions with leftovers in /tmp
  local tmpd
  tmpd="$(mktemp -d)"
  local tarball="$tmpd/zellij.tar.gz"

  if command -v download_with_retry >/dev/null 2>&1; then
    download_with_retry "$URL" "zellij ${VERSION}" "$tarball" || { rm -rf "$tmpd"; return 1; }
  else
    curl -fsSL --connect-timeout 10 -o "$tarball" "$URL" || { rm -rf "$tmpd"; return 1; }
  fi

  tar -xzf "$tarball" -C "$tmpd" zellij 2>/dev/null || true
  if [ -f "$tmpd/zellij" ]; then
    mv "$tmpd/zellij" "$HOME/.local/bin/zellij"
    chmod +x "$HOME/.local/bin/zellij"
    rm -rf "$tmpd"
    echo "[ezdora][zellij] ✅ Instalado em ~/.local/bin/zellij"
  else
    echo "[ezdora][zellij] ⚠️  Falha ao extrair o binário"
    rm -rf "$tmpd"
    return 1
  fi
}

# Execute instalação como app opcional
if command -v optional_install >/dev/null 2>&1; then
  optional_install "zellij" "install_zellij"
else
  install_zellij || {
    echo "[ezdora][zellij] ⚠️  Instalação falhou, mas continuando com outras instalações..."
    echo "[ezdora][zellij] 💡 Para tentar novamente: bash $(dirname "$0")/zellij.sh"
  }
fi

# Final verification
if command -v zellij >/dev/null 2>&1; then
  echo "[ezdora][zellij] ✅ Concluído. Executar com 'zellij' (ou 'zellij setup' para configurar)"
  echo "[ezdora][zellij] 💡 Para usar imediatamente: export PATH=\"\$HOME/.local/bin:\$PATH\""
else
  echo "[ezdora][zellij] ⚠️  Instalado mas não encontrado no PATH atual"
  echo "[ezdora][zellij] 🔄 Reinicie o terminal ou execute: source ~/.zshrc"
fi
