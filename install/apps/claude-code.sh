#!/usr/bin/env bash
set -euo pipefail

# Claude Code installation script - uses NATIVE installer (not npm)
# npm version is deprecated and can cause conflicts

if command -v claude >/dev/null 2>&1; then
  # Check if it's the native version (should be at ~/.local/bin/claude)
  CLAUDE_PATH=$(which claude)
  if [[ "$CLAUDE_PATH" == *".npm-global"* ]]; then
    echo "[ezdora][claude-code] WARNING: npm version detected. Removing and installing native..."
    npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true
  else
    echo "[ezdora][claude-code] Already installed (native). Skipping."
    exit 0
  fi
fi

echo "[ezdora][claude-code] Installing Claude Code via native installer..."

# Install via official installer
curl -fsSL https://claude.ai/install.sh | bash

# Verify installation
if [ -f "$HOME/.local/bin/claude" ]; then
  CLAUDE_VERSION=$("$HOME/.local/bin/claude" --version 2>/dev/null || echo "unknown")
  echo "[ezdora][claude-code] Installed successfully: $CLAUDE_VERSION"
else
  echo "[ezdora][claude-code] ERROR: Installation failed"
  exit 1
fi

# Create basic ~/.claude structure if it doesn't exist
if [ ! -d "$HOME/.claude" ]; then
  echo "[ezdora][claude-code] Creating ~/.claude directory structure..."
  mkdir -p "$HOME/.claude"
  mkdir -p "$HOME/.claude/plugins"
  mkdir -p "$HOME/.claude/projects"
  mkdir -p "$HOME/.claude/commands"

  # Copy settings template if available
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TEMPLATES_DIR="$SCRIPT_DIR/../templates/claude"

  if [ -f "$TEMPLATES_DIR/settings.json.template" ]; then
    cp "$TEMPLATES_DIR/settings.json.template" "$HOME/.claude/settings.json"
    echo "[ezdora][claude-code] Copied default settings.json"
  fi
else
  # Ensure commands directory exists even if ~/.claude already exists
  mkdir -p "$HOME/.claude/commands"
fi

# Create isolated profiles with shared projects directory
# Each profile has its own CLAUDE_CONFIG_DIR but shares ~/.claude/projects for conversation history
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/../templates/claude"
PROFILES_DIR="$HOME/.claude-profiles"

if [ -d "$TEMPLATES_DIR/profiles" ]; then
  echo "[ezdora][claude-code] Setting up Claude profiles..."
  mkdir -p "$PROFILES_DIR"

  for profile_template in "$TEMPLATES_DIR/profiles"/*.json; do
    [ -f "$profile_template" ] || continue
    profile_name=$(basename "$profile_template" .json)
    profile_dir="$PROFILES_DIR/$profile_name"

    if [ ! -d "$profile_dir" ]; then
      echo "[ezdora][claude-code] Creating profile: $profile_name"
      mkdir -p "$profile_dir"
      cp "$profile_template" "$profile_dir/settings.json"

      # Create shared symlinks (all profiles share ~/.claude/projects and ~/.claude/commands)
      ln -sf "$HOME/.claude/projects" "$profile_dir/projects"
      ln -sf "$HOME/.claude/commands" "$profile_dir/commands"
    else
      # Existing profile - ensure symlinks exist

      # Projects symlink
      if [ ! -L "$profile_dir/projects" ]; then
        if [ -d "$profile_dir/projects" ]; then
          echo "[ezdora][claude-code] Migrating $profile_name projects to shared directory..."
          cp -rn "$profile_dir/projects"/* "$HOME/.claude/projects"/ 2>/dev/null || true
          rm -rf "$profile_dir/projects"
        fi
        ln -sf "$HOME/.claude/projects" "$profile_dir/projects"
        echo "[ezdora][claude-code] Created shared projects symlink for: $profile_name"
      fi

      # Commands symlink (for global skills/commands)
      if [ ! -L "$profile_dir/commands" ]; then
        if [ -d "$profile_dir/commands" ]; then
          # Migrate any existing commands
          cp -rn "$profile_dir/commands"/* "$HOME/.claude/commands"/ 2>/dev/null || true
          rm -rf "$profile_dir/commands"
        fi
        ln -sf "$HOME/.claude/commands" "$profile_dir/commands"
        echo "[ezdora][claude-code] Created shared commands symlink for: $profile_name"
      fi
    fi
  done
fi

echo "[ezdora][claude-code] Done."
echo "[ezdora][claude-code] Run 'claude' to start, or 'claude auth' to authenticate."
echo "[ezdora][claude-code] Profiles available: clm (team-max), clt (team), clp (personal-max), clr (proton-max)"
