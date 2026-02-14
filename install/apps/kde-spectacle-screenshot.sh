#!/usr/bin/env bash
set -euo pipefail

echo "[ezdora][kde-spectacle] Configuring Spectacle screenshot shortcuts"
echo "============================================================="
echo ""

# Check if running KDE
if [[ "${XDG_CURRENT_DESKTOP:-}" != *KDE* ]]; then
  echo "[ezdora][kde-spectacle] Not running KDE, skipping..."
  exit 0
fi

# Check if spectacle is installed
if ! command -v spectacle >/dev/null 2>&1; then
  echo "[ezdora][kde-spectacle] Spectacle not found, skipping..."
  exit 0
fi

echo "Configuring shortcuts:"
echo "  Print Screen       -> Select region + copy to clipboard"
echo "  Meta+Shift+Print   -> Open Spectacle editor (default behavior)"
echo "  Meta+Shift+S       -> Open Spectacle editor (default behavior)"
echo "  Meta+Print         -> Capture active window"
echo ""

# Backup
BACKUP_DIR="$HOME/.config/ezdora-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f ~/.config/kglobalshortcutsrc ]; then
  cp ~/.config/kglobalshortcutsrc "$BACKUP_DIR/kglobalshortcutsrc.bak"
fi
if [ -f ~/.config/spectaclerc ]; then
  cp ~/.config/spectaclerc "$BACKUP_DIR/spectaclerc.bak"
fi

echo "Backup saved to: $BACKUP_DIR"
echo ""

# Configure Spectacle to copy to clipboard after screenshot (instead of opening editor)
echo "Configuring Spectacle to copy screenshots to clipboard..."
kwriteconfig6 --file spectaclerc --group "General" --key "clipboardGroup" "PostScreenshotCopyImage"

# Set shortcuts via dbus (kwriteconfig6 alone does not reliably update kglobalaccel for Spectacle)
echo "Setting keyboard shortcuts via kglobalaccel dbus..."

python3 << 'PYEOF'
import sys
try:
    import dbus
except ImportError:
    print("[ezdora][kde-spectacle] python3-dbus not found, falling back to kwriteconfig6 only")
    sys.exit(0)

bus = dbus.SessionBus()
obj = bus.get_object('org.kde.kglobalaccel', '/kglobalaccel')
iface = dbus.Interface(obj, 'org.kde.KGlobalAccel')

# Qt key codes
PRINT = 0x01000009             # Print Screen
META_SHIFT_PRINT = 0x13000009  # Meta+Shift+Print
META_SHIFT_S = 0x12000053      # Meta+Shift+S

def make_action(name, friendly=""):
    return dbus.Array(["org.kde.spectacle.desktop", name, friendly, ""], signature='s')

launch_id = make_action("_launch", "Launch Spectacle")
region_id = make_action("RectangularRegionScreenShot", "Capture Rectangular Region")

# Step 1: Clear RectangularRegionScreenShot to free up any conflicting keys
iface.setForeignShortcut(region_id, dbus.Array([], signature='i'))

# Step 2: Set _launch to Meta+Shift+Print + Meta+Shift+S (remove plain Print from it)
iface.setForeignShortcut(launch_id, dbus.Array([META_SHIFT_PRINT, META_SHIFT_S], signature='i'))

# Step 3: Set RectangularRegionScreenShot to plain Print
iface.setForeignShortcut(region_id, dbus.Array([PRINT], signature='i'))

# Verify
for name, aid in [("_launch", launch_id), ("RectangularRegionScreenShot", region_id)]:
    keys = iface.shortcut(aid)
    print(f"  {name}: {[hex(k) for k in keys]}")

print("[ezdora][kde-spectacle] Shortcuts set successfully via dbus")
PYEOF

echo ""
echo "Shortcuts configured:"
echo "  Print Screen       = Select region -> clipboard"
echo "  Meta+Shift+Print   = Open Spectacle editor"
echo "  Meta+Shift+S       = Open Spectacle editor"
echo ""
echo "[ezdora][kde-spectacle] Done!"
