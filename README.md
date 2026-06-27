# EzDora (Ez Fedora)

Um post-install minimalista para **Fedora 43+ KDE**, focado em instalar apps essenciais e configurar um ambiente de desenvolvimento completo com Claude Code, mise, e ferramentas modernas.

Inspirado no Omakub, com instaladores modulares (um app por arquivo).

## Como usar

```bash
# Uma linha (recomendado)
bash <(curl -fsSL https://raw.githubusercontent.com/takitani/ezdora/master/bootstrap.sh)

# Ou clonado localmente
git clone https://github.com/takitani/ezdora.git
cd ezdora && bash install.sh
```

### Notas
- Bootstrap clona via HTTPS (repo público), não precisa SSH
- Idempotente: pode reexecutar a qualquer momento

## O que instala

### Terminal e Shell
- **Kitty** - Terminal moderno com suporte Wayland
- **Zsh** - Shell com configuração avançada
- **Starship** - Prompt customizável
- **Antigen** - Gerenciador de plugins Zsh
- **Atuin** - Histórico de comandos aprimorado
- **Zoxide** - Navegação inteligente de diretórios

### Desenvolvimento
- **Claude Code** - AI coding assistant (npm global)
  - MCP servers (serena, claude-mem)
  - Multi-profile support (team, personal, etc.)
  - Writing-style guide ("não parecer IA") importado em todos os profiles
- **Mise** - Gerenciador de versões (Node, .NET, Python, Go, etc.)
- **Neovim** - Editor com LazyVim
- **VS Code** - Editor (via repo Microsoft)
- **JetBrains Toolbox** - IDEs JetBrains
- **Docker** - Containers

### Ferramentas CLI
- **uv** - Gerenciador de pacotes Python (rápido)
- **Bitwarden CLI** - Gerenciador de senhas
- **Lazydocker** - UI para Docker
- **Git, curl, wget, htop, tree** - Essenciais

### Apps Desktop (Flatpak)
- LocalSend, Discord, Slack, Spotify
- Obsidian, Postman, Mission Center
- ZapZap (WhatsApp), Telegram

### Configurações KDE
- Kitty como terminal padrão
- Ctrl+Alt+T para abrir terminal
- Animações configuradas para "Instant"
- Cedilla fix para pt-BR (ç via apostrophe+c)

### Apps opcionais (opt-in)

Pulados por padrão. Habilite com a variável de ambiente correspondente antes de rodar o `install.sh`:

| App | Variável | Descrição |
|-----|----------|-----------|
| **Zellij** | `EZDORA_INSTALL_ZELLIJ=true` | Terminal multiplexer/workspace ([zellij.dev](https://zellij.dev/)) |
| **Cursor** | `EZDORA_INSTALL_CURSOR=true` | Editor AI (fork do VS Code) |
| **Windsurf** | `EZDORA_INSTALL_WINDSURF=true` | Editor AI da Codeium |

```bash
# Exemplo: instalar tudo + Zellij
EZDORA_INSTALL_ZELLIJ=true bash install.sh

# Ou rodar só o instalador do Zellij
EZDORA_INSTALL_ZELLIJ=true bash install/apps/zellij.sh
```

## Estrutura

```
ezdora/
├── install.sh              # Script principal
├── bootstrap.sh            # Instalação remota
├── install/
│   ├── apps/               # Scripts individuais por app
│   ├── config/             # Scripts de configuração
│   └── templates/          # Templates (zshrc, starship, etc.)
├── packages/
│   ├── dnf.txt             # Pacotes DNF
│   └── flatpak.txt         # Apps Flatpak
└── archive/                # Scripts obsoletos (Ghostty, etc.)
```

## Claude Code Setup

O EzDora inclui setup completo para Claude Code:

```bash
# Após instalação
claude auth                 # Autenticar
claude                      # Iniciar

# Multi-profile (se configurado)
clm                         # Claude Team Max
clt                         # Claude Team
clp                         # Claude Personal
claude-profile              # Mostrar profile atual
```

### MCP Servers
- **serena** - Navegação semântica de código
- **claude-mem** - Memória/contexto

### Configuração de Profiles

Edite `~/.claude-profiles/*/settings.json` com seus UUIDs de organização:
- Encontre em: https://console.anthropic.com/settings/organization

### Writing style (não parecer IA)

`install/apps/claude-code-writing-style.sh` instala um guia de escrita em
`~/.claude/writing-style.md` e adiciona um `@import` em cada `CLAUDE.md` (base e
todos os profiles), então ele carrega em toda sessão. O guia cobre os "AI tells"
mais comuns (travessão, vocabulário de IA, bajulação, filler) com uma seção
pt-BR. Fonte: [blader/humanizer](https://github.com/blader/humanizer).

- Fonte única: edite `install/templates/claude/writing-style.md` e rode o script
  de novo para propagar.
- Idempotente: um marcador em comentário HTML protege o bloco de `@import`
  (comentários HTML são removidos antes de ir pro contexto do Claude, custo zero).
- Na primeira sessão após instalar, o Claude pede aprovação 1x do import externo.

## Templates

O EzDora usa templates com placeholders para configuração:

| Template | Descrição |
|----------|-----------|
| `zshrc.template` | Configuração Zsh completa |
| `starship.toml` | Prompt Starship |
| `mise-config.toml` | Versões de ferramentas |
| `claude/*.json` | Settings do Claude Code |

Placeholders suportados:
- `{{CLAUDE_UUID_*}}` - UUIDs de organização Claude
- `{{GOOGLE_API_KEY}}` - API key Google/Gemini
- `{{OP_ACCOUNT}}` - Conta 1Password

## Customização

### Adicionar pacotes
Edite antes de instalar:
- `packages/dnf.txt` - Pacotes DNF
- `packages/flatpak.txt` - Apps Flatpak

### Configurações locais
- `~/.zshrc.local` - Aliases e funções customizadas (auto-carregado)
- `~/.ezdora-config` - Variáveis para setup não-interativo

### Ferramentas opcionais (não incluídas)
- **devmon** - Monitor de desenvolvimento (ferramenta interna)
- **terraform** - Infrastructure as Code
- **flarectl** - Cloudflare CLI

## Requisitos

- Fedora 43 ou superior
- KDE Plasma
- Conexão internet

## Changelog

Ver [CHANGELOG.md](CHANGELOG.md)

## Contribuindo

Ver [AGENTS.md](AGENTS.md) para guidelines de desenvolvimento.
