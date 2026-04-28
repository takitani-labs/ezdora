#!/usr/bin/env bash
set -euo pipefail

# Install Cursor editor from official RPM.
# Opt-in: set EZDORA_INSTALL_CURSOR=true to enable
if [ "${EZDORA_INSTALL_CURSOR:-false}" != "true" ]; then
  echo "[ezdora][cursor] Skipping (set EZDORA_INSTALL_CURSOR=true to install)"
  exit 0
fi

if command -v cursor >/dev/null 2>&1; then
  echo "[ezdora][cursor] Já instalado. Pulando."
  exit 0
fi

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"

OUT="cursor-latest.rpm"

download_rpm() {
  local url="$1"
  echo "[ezdora][cursor] Baixando RPM de: $url"
  curl -fL --retry 3 --retry-all-errors --connect-timeout 15 \
    -H 'User-Agent: Mozilla/5.0' \
    -H 'Referer: https://www.cursor.com/' \
    -o "$OUT" "$url"
}

URLS=()
# 1) User-provided direct RPM link (if any)
if [ -n "${CURSOR_RPM_URL:-}" ]; then URLS+=("$CURSOR_RPM_URL"); fi
# 2) Known-good fallback RPM (pinned)
URLS+=("https://downloads.cursor.com/production/2f2737de9aa376933d975ae30290447c910fdf46/linux/x64/rpm/x86_64/cursor-1.5.11.el8.x86_64.rpm")
# 3) Generic downloader endpoint
URLS+=("https://downloader.cursor.sh/linux/rpm")

DL_OK=0
for u in "${URLS[@]}"; do
  if download_rpm "$u" 2>/dev/null; then DL_OK=1; break; fi
done

# Fallback: use a pre-downloaded RPM from Downloads if present
if [ $DL_OK -eq 0 ]; then
  CAND=$(ls -1 "$HOME"/Downloads/*[Cc]ursor*.rpm 2>/dev/null | head -n1 || true)
  if [ -n "$CAND" ]; then
    echo "[ezdora][cursor] Usando RPM local: $CAND"
    cp "$CAND" "$OUT"
    DL_OK=1
  fi
fi

if [ $DL_OK -eq 0 ]; then
  echo "[ezdora][cursor] Não foi possível baixar o RPM automaticamente."
  echo "[ezdora][cursor] Baixe manualmente o .rpm do Cursor e salve em ~/Downloads, ou"
  echo "[ezdora][cursor] exporte CURSOR_RPM_URL=\"<link-direto-.rpm>\" e execute novamente."
  exit 1
fi

# Sanity check: ensure it's an RPM file
if ! file "$OUT" | grep -qi 'RPM'; then
  echo "[ezdora][cursor] O arquivo baixado não parece ser um RPM válido." >&2
  exit 1
fi

echo "[ezdora][cursor] Instalando..."
sudo dnf install -y "$OUT"

echo "[ezdora][cursor] Concluído. Execute com 'cursor'."
