# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Claude writing-style guide** (`install/apps/claude-code-writing-style.sh`)
  - Deploys a shared "write so it doesn't read as AI" guide to
    `~/.claude/writing-style.md` and wires it into every Claude memory file
    (base `~/.claude/CLAUDE.md` plus each `~/.claude-profiles/*/CLAUDE.md`) via
    an `@~/.claude/writing-style.md` import, so it loads in every session across
    all profiles.
  - Single source of truth in `install/templates/claude/writing-style.md`: edit
    it and re-run to propagate. Idempotent (an HTML-comment marker guards the
    import block; markers are stripped from Claude's context, so they cost no
    tokens). Only touches profile dirs that already exist.
  - Covers English prose tells (em dashes, AI vocabulary, sycophancy, filler)
    plus a short pt-BR section. Based on github.com/blader/humanizer.
- **ZapZap memory guard** (`install/apps/zapzap-memguard.sh`)
  - Installs a systemd user timer that restarts ZapZap (WhatsApp) when its
    summed RSS crosses 20 GB. ZapZap uses QtWebEngine and leaks memory over long
    uptimes (observed at ~43 GB); this caps it automatically.
  - Checks every 5 minutes; idempotent; tolerant of headless/CI runs.

## v0.2.0 — 2025-12-30 — Claude Code & Modern Tooling

### Added
- **Claude Code** full setup
  - Installation via npm global (`install/apps/claude-code.sh`)
  - Multi-profile system (team-max, team, personal-max, proton-max)
  - MCP servers integration (serena, claude-mem)
  - Auto-sync plugin versions across profiles
  - Profile switching via aliases (`clm`, `clt`, `clp`, `clr`)
- **Templates system** for configuration
  - `zshrc.template` with placeholders for secrets
  - `starship.toml` and `mise-config.toml` templates
  - Claude settings templates with profile support
- **New tools**
  - `uv` - Fast Python package manager from Astral
  - `bitwarden-cli` - Password manager CLI
- **Shell enhancements**
  - Advanced .zshrc with 340+ lines of configuration
  - Conditional Atuin vs traditional history
  - `rider()` function for JetBrains Rider + Mise integration
  - `tp()` for tmux session management
  - `dev()` for project dev.sh discovery
- **Configuration scripts**
  - `install/config/zshrc-setup.sh` - Interactive zshrc generator
  - Support for `~/.zshrc.local` for custom additions
  - Support for `~/.ezdora-config` for non-interactive setup

### Changed
- **Fedora version**: Minimum 42 → 43
- **Terminal**: Ghostty → Kitty (better Wayland/KDE support)
- **README**: Completely rewritten with Claude Code documentation

### Deprecated
- Ghostty scripts moved to `archive/ghostty/`

### Removed
- Ghostty as default terminal (still available in archive)

## v0.1.0 — initial cut

- Bootstrap via HTTPS one‑liner; clones to `~/.local/share/ezdora`.
- Modular per‑app installers in `install/apps/*.sh`.
- KDE integration: Ghostty como terminal padrão e `Ctrl+Alt+T` remapeado.
- Fonts: instala CascadiaMono, JetBrainsMono (Nerd Fonts) e iA Writer; seletor interativo (gum/fzf) de fonte e tamanho; aplica ao Ghostty.
- Shell: define zsh; Starship com preset rico (hora, git, linguagens, .NET), histórico preservado.
- mise: instala `node@latest` (npm) e `dotnet@9` globalmente; `mise activate` no zsh/bash.
- Navegadores/Apps: Google Chrome (repo oficial), VLC (RPM Fusion), LocalSend, Discord, Obsidian, Mission Center, Postman, Slack, ZapZap.
- Terminais/CLI: Ghostty (COPR), htop, tree, unzip/zip, wget/curl, xclip, wl-clipboard, vim, git, zsh.
- Neovim: instala via DNF com `python3-neovim`; LazyVim starter se não houver config; transparência com toggle `:EzTransparencyToggle`.
- Docker: instala Docker Engine (repo oficial), habilita serviço/grupo; lazydocker.
- JetBrains Toolbox: instala via tarball oficial em `~/.local/share/JetBrains/Toolbox` e symlink em `~/.local/bin`.

