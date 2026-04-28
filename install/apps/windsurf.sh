#!/usr/bin/env bash
set -euo pipefail

# Install Windsurf Editor - AI-powered code editor from Codeium
# Opt-in: set EZDORA_INSTALL_WINDSURF=true to enable
if [ "${EZDORA_INSTALL_WINDSURF:-false}" != "true" ]; then
    echo "[ezdora][windsurf] Skipping (set EZDORA_INSTALL_WINDSURF=true to install)"
    exit 0
fi

echo "[ezdora][windsurf] Instalando Windsurf Editor..."

# Check if already installed
if rpm -q windsurf >/dev/null 2>&1; then
    echo "[ezdora][windsurf] Windsurf já está instalado"
    echo "[ezdora][windsurf] Para atualizar, execute: sudo dnf update windsurf"
    exit 0
fi

# Check if repository is already configured
REPO_FILE="/etc/yum.repos.d/windsurf.repo"
if [ ! -f "$REPO_FILE" ]; then
    echo "[ezdora][windsurf] Configurando repositório Windsurf..."
    
    # Import the signing key
    echo "[ezdora][windsurf] Importando chave GPG..."
    sudo rpm --import https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/yum/RPM-GPG-KEY-windsurf
    
    # Add the repository
    echo "[ezdora][windsurf] Adicionando repositório..."
    echo -e "[windsurf]
name=Windsurf Repository
baseurl=https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/yum/repo/
enabled=1
autorefresh=1
gpgcheck=1
gpgkey=https://windsurf-stable.codeiumdata.com/wVxQEIWkwPUEAGf3/yum/RPM-GPG-KEY-windsurf" | sudo tee "$REPO_FILE" > /dev/null
    
    echo "[ezdora][windsurf] Repositório configurado com sucesso"
else
    echo "[ezdora][windsurf] Repositório já está configurado"
fi

# Update repository metadata
echo "[ezdora][windsurf] Atualizando metadados do repositório..."
sudo dnf check-update windsurf 2>/dev/null || true

# Install Windsurf
echo "[ezdora][windsurf] Instalando Windsurf Editor..."
if sudo dnf install -y windsurf; then
    echo "[ezdora][windsurf] ✅ Windsurf Editor instalado com sucesso!"
    echo "[ezdora][windsurf] Para executar: windsurf"
    echo "[ezdora][windsurf] Ou procure por 'Windsurf' no menu de aplicações"
    
    # Check if binary exists and is executable
    if command -v windsurf >/dev/null 2>&1; then
        echo "[ezdora][windsurf] Versão instalada: $(windsurf --version 2>/dev/null | head -1 || echo 'não detectada')"
    fi
else
    echo "[ezdora][windsurf] ❌ ERRO: Falha ao instalar Windsurf Editor"
    echo "[ezdora][windsurf] Verifique sua conexão com a internet e tente novamente"
    exit 1
fi

echo "[ezdora][windsurf] Windsurf Editor - AI-powered code editor está pronto para uso!"