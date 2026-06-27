#!/usr/bin/env bash
set -euo pipefail

# Install Tabularis - open-source desktop SQL workspace (Tauri/Rust) for
# PostgreSQL, MySQL/MariaDB, SQLite and 12+ more via plugins, with a built-in
# MCP server for AI agents. https://tabularis.dev | github.com/TabularisDB/tabularis
#
# Installs the OFFICIAL signed .rpm from GitHub Releases and verifies its
# Tauri/minisign signature against the project's pinned public key BEFORE
# installing (fail-closed). We deliberately avoid the flatpark.org Flatpak
# referenced in upstream's README: it is an unofficial third-party repackager,
# not on Flathub, with no documented signing.
#
# Opt-in: set EZDORA_INSTALL_TABULARIS=true to enable
if [ "${EZDORA_INSTALL_TABULARIS:-false}" != "true" ]; then
  echo "[ezdora][tabularis] Skipping (set EZDORA_INSTALL_TABULARIS=true to install)"
  exit 0
fi

# Idempotency: skip if already installed (RPM owns the package name "tabularis")
if rpm -q tabularis >/dev/null 2>&1 || command -v tabularis >/dev/null 2>&1; then
  echo "[ezdora][tabularis] Já instalado. Pulando. (O app se atualiza sozinho via updater assinado.)"
  exit 0
fi

REPO="TabularisDB/tabularis"
# Pinned Tauri/minisign public key (from src-tauri/tauri.conf.json -> plugins.updater.pubkey).
# This same key signs the release artifacts' .sig files. key id: 64764B3DB28B1DB7
PUBKEY="RWS3HYuyPUt2ZDXvdI8BaTJXN+vUtXKGkN+unkaHusqiP+OVoiyqZNYp"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
cd "$tmpdir"

echo "[ezdora][tabularis] Descobrindo a última release..."

# --- Resolve the latest x86_64 RPM asset URL --------------------------------
RPM_URL=""
# Method A: GitHub API (no auth needed for public repos; may be rate-limited)
API_JSON="$(curl -fsSL --connect-timeout 15 -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)"
if [ -n "$API_JSON" ]; then
  RPM_URL="$(printf '%s' "$API_JSON" \
    | grep -oE 'https://github.com/[^"]*-1\.x86_64\.rpm' | head -n1 || true)"
fi
# Method B: derive version from the updater manifest (stable URL, no rate limit)
if [ -z "$RPM_URL" ]; then
  echo "[ezdora][tabularis] API indisponível; usando latest.json para derivar a versão..."
  VER="$(curl -fsSL --connect-timeout 15 \
    "https://github.com/${REPO}/releases/latest/download/latest.json" 2>/dev/null \
    | grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 \
    | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/' || true)"
  VER="${VER#v}"
  if [ -n "$VER" ]; then
    RPM_URL="https://github.com/${REPO}/releases/latest/download/tabularis-${VER}-1.x86_64.rpm"
  fi
fi
if [ -z "$RPM_URL" ]; then
  echo "[ezdora][tabularis] ❌ Não foi possível descobrir a URL do RPM. Verifique sua conexão." >&2
  echo "[ezdora][tabularis]    Baixe manualmente de https://github.com/${REPO}/releases" >&2
  exit 1
fi
SIG_URL="${RPM_URL}.sig"

RPM_FILE="$tmpdir/tabularis.x86_64.rpm"
SIG_FILE="$tmpdir/tabularis.x86_64.rpm.sig"

echo "[ezdora][tabularis] Baixando RPM:  $RPM_URL"
curl -fL --retry 3 --retry-all-errors --connect-timeout 15 -o "$RPM_FILE" "$RPM_URL"
echo "[ezdora][tabularis] Baixando assinatura: $SIG_URL"
curl -fL --retry 3 --retry-all-errors --connect-timeout 15 -o "$SIG_FILE" "$SIG_URL"

# Sanity: it must actually be an RPM
if ! file "$RPM_FILE" | grep -qi 'RPM'; then
  echo "[ezdora][tabularis] ❌ O arquivo baixado não é um RPM válido. Abortando." >&2
  exit 1
fi

# --- Verify the signature (fail-closed) -------------------------------------
# The .sig is Tauri's base64-wrapped minisign signature (Ed25519, BLAKE2b-512
# prehash). We verify it against the pinned PUBKEY before trusting the package.
verify_rpm_signature() {
  local rpm="$1" sig="$2"
  local minisig="$tmpdir/tabularis.minisig"

  # Tauri publishes the .sig base64-encoded; decode to raw minisign form.
  if head -c 18 "$sig" 2>/dev/null | grep -q "untrusted comment"; then
    cp "$sig" "$minisig"
  else
    base64 -d "$sig" > "$minisig" 2>/dev/null || cp "$sig" "$minisig"
  fi

  # 1) Prefer the minisign CLI if it is already available.
  if command -v minisign >/dev/null 2>&1; then
    if minisign -Vm "$rpm" -P "$PUBKEY" -x "$minisig" >/dev/null 2>&1; then
      echo "[ezdora][tabularis] ✅ Assinatura verificada (minisign CLI)"; return 0
    fi
    echo "[ezdora][tabularis] ❌ Assinatura INVÁLIDA (minisign CLI)"; return 1
  fi

  # 2) Fall back to Python + cryptography (preinstalado no Fedora, sem sudo).
  if command -v python3 >/dev/null 2>&1 && python3 -c "import cryptography" >/dev/null 2>&1; then
    if TAB_PUBKEY="$PUBKEY" python3 - "$rpm" "$minisig" <<'PY'
import base64, hashlib, os, sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from cryptography.exceptions import InvalidSignature
pk = base64.b64decode(os.environ["TAB_PUBKEY"])
pub = Ed25519PublicKey.from_public_bytes(pk[10:])
keyid = pk[2:10]
lines = open(sys.argv[2]).read().splitlines()
sig = base64.b64decode(lines[1])
if sig[2:10] != keyid:
    print("key id mismatch"); sys.exit(1)
data = open(sys.argv[1], "rb").read()
signed = hashlib.blake2b(data, digest_size=64).digest() if sig[:2] == b"ED" else data
try:
    pub.verify(sig[10:], signed)
except InvalidSignature:
    print("invalid signature"); sys.exit(1)
sys.exit(0)
PY
    then
      echo "[ezdora][tabularis] ✅ Assinatura Ed25519 verificada (python/cryptography)"; return 0
    fi
    echo "[ezdora][tabularis] ❌ Assinatura INVÁLIDA (python/cryptography)"; return 1
  fi

  # 3) Last resort: install minisign, then verify.
  echo "[ezdora][tabularis] minisign/python indisponíveis; instalando minisign para verificar..."
  if sudo dnf install -y minisign >/dev/null 2>&1 && command -v minisign >/dev/null 2>&1; then
    if minisign -Vm "$rpm" -P "$PUBKEY" -x "$minisig" >/dev/null 2>&1; then
      echo "[ezdora][tabularis] ✅ Assinatura verificada (minisign CLI)"; return 0
    fi
    echo "[ezdora][tabularis] ❌ Assinatura INVÁLIDA (minisign CLI)"; return 1
  fi

  echo "[ezdora][tabularis] ❌ Não há ferramenta para verificar a assinatura (minisign/python+cryptography)." >&2
  return 1
}

echo "[ezdora][tabularis] Verificando a assinatura do RPM contra a chave fixada do projeto..."
if ! verify_rpm_signature "$RPM_FILE" "$SIG_FILE"; then
  echo "[ezdora][tabularis] ❌ FALHA NA VERIFICAÇÃO DE ASSINATURA — instalação abortada (fail-closed)." >&2
  echo "[ezdora][tabularis]    O RPM não corresponde à chave de assinatura oficial. NÃO instale este arquivo." >&2
  exit 1
fi

# --- Install ----------------------------------------------------------------
# The RPM is NOT GPG-signed (upstream signs with Tauri/minisign, which we just
# verified), so a local GPG check would reject it. --nogpgcheck is correct here.
echo "[ezdora][tabularis] Instalando o RPM verificado..."
if ! sudo dnf install -y "$RPM_FILE" 2>"$tmpdir/dnf.err"; then
  if grep -qiE 'gpg|signature|not signed|unsigned' "$tmpdir/dnf.err"; then
    echo "[ezdora][tabularis] RPM sem assinatura GPG (usa minisign, já verificado). Reinstalando com --nogpgcheck..."
    sudo dnf install -y --nogpgcheck "$RPM_FILE"
  else
    cat "$tmpdir/dnf.err" >&2
    exit 1
  fi
fi

# --- Post-install security notes (from ezdora's pre-install security audit) --
echo "[ezdora][tabularis] ✅ Instalado. Execute pelo menu de apps ou com 'tabularis'."
cat <<'NOTE'
[ezdora][tabularis] ⚠️  Notas de segurança (leia antes de usar):
  • SENHAS: ative "Save in keychain" em CADA conexão. Por padrão (DB) isso vem
    DESLIGADO e as senhas ficam em texto plano em ~/.config/tabularis/connections.json
  • PLUGINS: o marketplace roda código nativo NÃO assinado e NÃO isolado, com acesso
    às suas credenciais. Só instale plugins de autores em quem você confia.
  • IA/MCP: recursos de IA enviam schema + queries para o provider que VOCÊ configurar
    (OpenAI/Anthropic/etc.). Para manter tudo local, use Ollama (localhost:11434).
  • O app contata api.github.com no início (checagem de update; só IP, opt-out nas prefs).
NOTE
