#!/usr/bin/env bash
set -euo pipefail

# Install the Claude Desktop app (Linux beta) on Fedora via a Debian-based
# distrobox container, since Anthropic's beta only ships for Debian/Ubuntu.
# Docs: https://code.claude.com/docs/en/desktop-linux
#
# Opt-in: set EZDORA_INSTALL_CLAUDE_DESKTOP=true to enable.
# Standalone:
#   EZDORA_INSTALL_CLAUDE_DESKTOP=true bash install/apps/claude-desktop.sh
#
# Tunables (env vars):
#   CLAUDE_DESKTOP_BOX        container name        (default: claude-desktop)
#   CLAUDE_DESKTOP_IMAGE      base image            (default: ubuntu:24.04)
#   CLAUDE_DESKTOP_NO_SANDBOX pass --no-sandbox     (default: true)
#                             Electron's sandbox usually fails inside a rootless
#                             container; disabling it is the pragmatic default.
#                             Set to false to keep it and debug launch issues.

if [ "${EZDORA_INSTALL_CLAUDE_DESKTOP:-false}" != "true" ]; then
  echo "[ezdora][claude-desktop] Skipping (set EZDORA_INSTALL_CLAUDE_DESKTOP=true to install)"
  exit 0
fi

log() { echo "[ezdora][claude-desktop] $*"; }

BOX="${CLAUDE_DESKTOP_BOX:-claude-desktop}"
IMAGE="${CLAUDE_DESKTOP_IMAGE:-ubuntu:24.04}"

# Exact-match existence check against the container backend. Avoids the
# false positives of 'distrobox list | grep -w' (hyphens aren't word chars,
# so "claude-desktop" would match "claude-desktop-v2").
box_exists() {
  { command -v podman >/dev/null 2>&1 && podman container exists "$BOX" 2>/dev/null; } && return 0
  { command -v docker >/dev/null 2>&1 && docker container inspect "$BOX" >/dev/null 2>&1; } && return 0
  return 1
}

main() {
  # --- architecture -> Debian arch for the apt repo ---
  local deb_arch
  case "$(uname -m)" in
    x86_64)        deb_arch="amd64" ;;
    aarch64|arm64) deb_arch="arm64" ;;
    *)
      log "⚠️  Arquitetura não suportada pelo beta: $(uname -m)"
      return 1
      ;;
  esac

  # --- container backend (distrobox needs podman or docker) ---
  if ! command -v podman >/dev/null 2>&1 && ! command -v docker >/dev/null 2>&1; then
    log "⚠️  Nenhum backend de container (podman/docker) encontrado."
    log "    Instale um antes: sudo dnf install -y podman"
    return 1
  fi

  # --- distrobox on the host ---
  if ! command -v distrobox >/dev/null 2>&1; then
    log "Instalando distrobox via DNF..."
    sudo dnf install -y distrobox || { log "⚠️  Falha ao instalar distrobox"; return 1; }
  fi

  # --- create the Ubuntu box (idempotent) ---
  if box_exists; then
    log "Container '$BOX' já existe. Reaproveitando."
  else
    log "Criando container '$BOX' ($IMAGE)... (o primeiro pull pode demorar)"
    distrobox create --name "$BOX" --image "$IMAGE" --yes \
      || { log "⚠️  Falha ao criar o container"; return 1; }
  fi

  # --- extra Electron flags for the exported launcher ---
  local extra_flags="--ozone-platform-hint=auto"
  if [ "${CLAUDE_DESKTOP_NO_SANDBOX:-true}" = "true" ]; then
    extra_flags="--no-sandbox ${extra_flags}"
    log "ℹ️  Exportando com --no-sandbox (sandbox do Electron não funciona em container rootless)."
    log "    Para manter o sandbox: CLAUDE_DESKTOP_NO_SANDBOX=false"
  fi

  # --- provision inside the box (apt repo + install + export .desktop) ---
  # 'distrobox enter -- bash -c "<multi-word string>"' is mangled: distrobox
  # re-splits the command on whitespace, so a here-string command breaks apart.
  # Write the script to a file instead (the host home is bind-mounted into the
  # box at the same path) and run it by path. Host expands ${deb_arch} and
  # ${extra_flags}; everything else runs inside the box.
  mkdir -p "$HOME/.cache"
  local provision_file
  provision_file=$(mktemp "$HOME/.cache/ezdora-cd-provision.XXXXXX.sh") \
    || { log "⚠️  Falha ao criar arquivo temporário de provisionamento"; return 1; }

  cat > "$provision_file" <<PROV
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
echo "[ezdora][claude-desktop] (box) preparando apt..."
sudo apt-get update -y
sudo apt-get install -y curl ca-certificates
if command -v claude-desktop >/dev/null 2>&1; then
  echo "[ezdora][claude-desktop] (box) claude-desktop já instalado."
else
  echo "[ezdora][claude-desktop] (box) adicionando repositório da Anthropic..."
  sudo curl -fsSLo /usr/share/keyrings/claude-desktop-archive-keyring.asc https://downloads.claude.ai/claude-desktop/key.asc
  echo "deb [arch=${deb_arch} signed-by=/usr/share/keyrings/claude-desktop-archive-keyring.asc] https://downloads.claude.ai/claude-desktop/apt/stable stable main" | sudo tee /etc/apt/sources.list.d/claude-desktop.list >/dev/null
  sudo apt-get update -y
  sudo apt-get install -y claude-desktop
fi
echo "[ezdora][claude-desktop] (box) exportando atalho para o menu do host..."
distrobox-export --app claude-desktop --delete >/dev/null 2>&1 || true
distrobox-export --app claude-desktop --extra-flags "${extra_flags}" \
  || echo "[ezdora][claude-desktop] (box) ⚠️  Falha ao exportar atalho; o app está instalado. Rode: distrobox enter ${BOX} -- claude-desktop"
PROV

  log "Provisionando dentro do container..."
  if distrobox enter "$BOX" -- bash "$provision_file"; then
    rm -f "$provision_file"
  else
    rm -f "$provision_file"
    log "⚠️  Falha ao provisionar o Claude Desktop no container"
    return 1
  fi

  return 0
}

if main; then
  log "✅ Concluído."
  log "   Abra pelo menu do KDE (procure por 'Claude') ou rode:"
  log "     distrobox enter $BOX -- claude-desktop"
  log "   Atualizar depois:"
  log "     distrobox enter $BOX -- bash -c 'sudo apt update && sudo apt upgrade -y'"
  log "   Remover:"
  log "     distrobox rm -f $BOX   (e apague o atalho em ~/.local/share/applications)"
else
  log "⚠️  Instalação não concluída, mas seguindo com o restante do EzDora."
  log "💡 Para tentar de novo: EZDORA_INSTALL_CLAUDE_DESKTOP=true bash $(dirname "$0")/claude-desktop.sh"
  exit 0
fi
