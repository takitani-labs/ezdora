#!/usr/bin/env bash
set -euo pipefail

# Restart ZapZap (WhatsApp Flatpak) when its RAM crosses a threshold.
# ZapZap uses QtWebEngine and leaks memory over long uptimes (seen at ~43 GB once);
# a systemd user timer caps it. Installs a guard script + a user service/timer.

BIN_DIR="$HOME/.local/bin"
UNIT_DIR="$HOME/.config/systemd/user"
SCRIPT="$BIN_DIR/zapzap-memguard.sh"

echo "[ezdora/zapzap-memguard] Instalando guarda de memória do ZapZap..."

mkdir -p "$BIN_DIR" "$UNIT_DIR"

# --- guard script ---
cat > "$SCRIPT" <<'GUARD'
#!/usr/bin/env bash
# Restart ZapZap (WhatsApp Flatpak) when its resident memory exceeds a threshold.
# ZapZap uses QtWebEngine and leaks RAM over long uptimes (seen at ~43 GB once);
# this caps it. Driven by the zapzap-memguard.timer systemd user timer.
set -uo pipefail

APP="com.rtosta.zapzap"
THRESHOLD_MB=20480   # 20 GiB. Restart when summed RSS crosses this. Edit to taste.

# Sum VmRSS (in MB) across every process living in a ZapZap flatpak cgroup.
# Aggregates multiple zapzap scopes if more than one instance is running.
rss_kb=0
for cg in /proc/[0-9]*/cgroup; do
  grep -q "$APP" "$cg" 2>/dev/null || continue
  pid=${cg#/proc/}; pid=${pid%/cgroup}
  v=$(awk '/^VmRSS:/{print $2}' "/proc/$pid/status" 2>/dev/null) || continue
  rss_kb=$((rss_kb + ${v:-0}))
done
rss_mb=$((rss_kb / 1024))

if (( rss_mb == 0 )); then
  echo "ZapZap não está rodando; nada a fazer."
  exit 0
fi

if (( rss_mb <= THRESHOLD_MB )); then
  echo "ZapZap em ${rss_mb} MB (limite ${THRESHOLD_MB} MB) — OK."
  exit 0
fi

echo "ZapZap em ${rss_mb} MB > ${THRESHOLD_MB} MB — reiniciando."
flatpak kill "$APP" 2>/dev/null || true

# Espera encerrar (até ~15s) antes de relançar.
for _ in $(seq 1 15); do
  pgrep -f "application-name=ZapZap" >/dev/null 2>&1 || break
  sleep 1
done

# Relança em um serviço transiente próprio, pra sobreviver ao fim deste script.
# Herda o ambiente gráfico do gerenciador de usuário (Wayland/X11 + D-Bus).
systemd-run --user --collect --quiet flatpak run "$APP"
echo "ZapZap reiniciado em ${rss_mb} MB."
GUARD
chmod +x "$SCRIPT"

# --- systemd user service ---
cat > "$UNIT_DIR/zapzap-memguard.service" <<'SERVICE'
[Unit]
Description=Restart ZapZap when its memory exceeds the threshold

[Service]
Type=oneshot
ExecStart=%h/.local/bin/zapzap-memguard.sh
SERVICE

# --- systemd user timer ---
cat > "$UNIT_DIR/zapzap-memguard.timer" <<'TIMER'
[Unit]
Description=Check ZapZap memory every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
TIMER

# --- ativar (tolerante a ambiente sem bus de usuário, ex. headless/CI) ---
if systemctl --user show-environment >/dev/null 2>&1; then
  systemctl --user daemon-reload
  systemctl --user enable --now zapzap-memguard.timer
  echo "[ezdora/zapzap-memguard] ✓ Timer ativado (checa a cada 5 min, limite 20 GB)."
else
  echo "[ezdora/zapzap-memguard] Sem bus systemd de usuário; arquivos instalados."
  echo "[ezdora/zapzap-memguard] Ative depois com: systemctl --user enable --now zapzap-memguard.timer"
fi
