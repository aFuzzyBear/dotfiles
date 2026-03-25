#!/usr/bin/env bash
# FuzzyOS — Environment Setup
# https://github.com/aFuzzyBear/dotfiles
#
# Usage:
#   # With your own dotfiles repo:
#   curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash -s -- \
#     --dotfiles https://github.com/yourname/dotfiles.git
#
#   # Without dotfiles (bare environment — mise + tools only):
#   curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash -s -- \
#     --no-dotfiles
#
#   # Default (applies aFuzzyBear dotfiles — for fuzzybook machines):
#   curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash
#
# What this script owns:
#   The irreducible minimum that cannot be managed by mise — because mise
#   doesn't exist yet. Everything else is owned by the mise task graph.
#
#   1. apt base packages   — system-level deps mise cannot manage
#   2. gh CLI              — needed before chezmoi (SSH key upload)
#   3. GitHub auth         — needed before chezmoi (repo access)
#   4. SSH key             — machine identity for git
#   5. mise                — the tool manager itself
#   6. chezmoi             — materialises dotfiles from your repo
#   7. mise install        — tools declared in ~/.config/mise/config.toml
#   8. mise run bootstrap  — hands off to the task graph (if dotfiles provide one)
#
# After this script completes, the mise task graph owns everything.
# To verify environment health: mise run doctor

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "\n${BLUE}→${NC} $1"; }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
bold()  { echo -e "${BOLD}$1${NC}"; }
die()   { echo -e "\n${YELLOW}✗ $1${NC}" >&2; exit 1; }

# ── Defaults ──────────────────────────────────────────────────────────────────
DEFAULT_DOTFILES="https://github.com/aFuzzyBear/dotfiles.git"
DOTFILES_REPO="$DEFAULT_DOTFILES"
SKIP_DOTFILES=false

# ── Argument parsing ──────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dotfiles)
      DOTFILES_REPO="$2"
      shift 2
      ;;
    --no-dotfiles)
      SKIP_DOTFILES=true
      shift
      ;;
    --help|-h)
      echo "Usage: setup.sh [--dotfiles <repo-url>] [--no-dotfiles]"
      echo ""
      echo "  --dotfiles <url>   Apply a chezmoi-compatible dotfiles repo after bootstrap"
      echo "  --no-dotfiles      Skip dotfiles entirely — bare mise environment only"
      echo ""
      echo "  Default dotfiles: $DEFAULT_DOTFILES"
      exit 0
      ;;
    *)
      die "Unknown argument: $1. Run with --help for usage."
      ;;
  esac
done

clear
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold "  🐻 FuzzyOS — Environment Setup 🐻"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ "$SKIP_DOTFILES" == true ]]; then
  echo "  Mode: bare environment (no dotfiles)"
else
  echo "  Dotfiles: $DOTFILES_REPO"
fi
echo ""

# ── Sanity checks ─────────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Linux" ]] || die "Linux/WSL only. For macOS see: docs/macos.md"
command -v apt &>/dev/null      || die "apt not found — Ubuntu/Debian only"

# ── 1. Base packages ──────────────────────────────────────────────────────────
info "Installing base packages..."
sudo apt update -q
sudo apt install -y \
  curl \
  git \
  zsh \
  gpg \
  unzip \
  jq \
  build-essential \
  ca-certificates \
  wslu \
  pinentry-gtk2 \
  syncthing \
  pass \
  bat \
  fd-find \
  ripgrep \
  btop
ok "Base packages installed"

mkdir -p ~/.local/bin
[[ -f /usr/bin/batcat ]] && ln -sf /usr/bin/batcat ~/.local/bin/bat && ok "bat symlinked"
[[ -f /usr/bin/fdfind ]] && ln -sf /usr/bin/fdfind ~/.local/bin/fd  && ok "fd symlinked"
export PATH="$HOME/.local/bin:$PATH"

# ── 2. gh CLI ─────────────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  info "Installing gh CLI..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt update -q && sudo apt install -y gh
  ok "gh CLI installed"
else
  ok "gh CLI already installed"
fi

# ── 3. GitHub auth ────────────────────────────────────────────────────────────
if ! gh auth status &>/dev/null; then
  info "Authenticating with GitHub..."
  echo "  A browser window will open — complete the auth flow there."
  gh auth login --web -h github.com -s admin:public_key
fi
ok "GitHub authenticated"

# ── 4. SSH key ────────────────────────────────────────────────────────────────
if [[ ! -f ~/.ssh/id_ed25519 ]]; then
  info "Generating SSH key for this machine..."
  GIT_EMAIL=$(gh api user --jq '.email // "\(.id)+\(.login)@users.noreply.github.com"' 2>/dev/null || echo "")
  ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f ~/.ssh/id_ed25519 -N ""
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add ~/.ssh/id_ed25519
  gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)-wsl-$(date +%Y%m%d)"
  ok "SSH key generated and added to GitHub"
else
  ok "SSH key already exists"
fi

# ── 5. mise ───────────────────────────────────────────────────────────────────
if ! command -v ~/.local/bin/mise &>/dev/null; then
  info "Installing mise..."
  curl https://mise.run | sh
  ok "mise installed"
else
  ok "mise already installed"
fi

export PATH="$HOME/.local/bin:$PATH"
eval "$(~/.local/bin/mise activate bash)"

# ── 6. chezmoi + dotfiles ─────────────────────────────────────────────────────
info "Installing chezmoi via mise..."
mise use -g chezmoi
mise reshim
eval "$(~/.local/bin/mise activate bash)" # re-activate to pick up chezmoi in PATH
ok "chezmoi installed"

if [[ "$SKIP_DOTFILES" == true ]]; then
  warn "Skipping dotfiles — bare mise environment only"
  warn "Apply dotfiles later with: chezmoi init --apply <your-repo>"
else
  info "Applying dotfiles from $DOTFILES_REPO..."
  if [[ ! -d ~/.local/share/chezmoi/.git ]]; then
    mise x -- chezmoi init --apply "$DOTFILES_REPO"
  else
    warn "chezmoi already initialised — running update instead"
    mise x -- chezmoi update
  fi
  ok "Dotfiles applied"
fi

# ── 7. mise tools ─────────────────────────────────────────────────────────────
# Tool versions declared in ~/.config/mise/config.toml (materialised above).
# If no dotfiles were applied, this installs whatever global tools are already
# declared — or nothing if config.toml doesn't exist yet.
if [[ -f ~/.config/mise/config.toml ]]; then
  info "Installing global tools via mise..."
  mise install
  mise reshim
  ok "mise tools installed"
else
  warn "No ~/.config/mise/config.toml found — skipping mise install"
  warn "Add tools with: mise use -g <tool>"
fi

# ── 8. Bootstrap task graph ───────────────────────────────────────────────────
# Hand off to mise if the dotfiles provide a bootstrap task.
# Gracefully skips if no task graph is present.
if mise tasks 2>/dev/null | grep -q "^bootstrap"; then
  info "Running bootstrap task graph..."
  mise run bootstrap
else
  warn "No bootstrap task found — skipping"
  warn "If your dotfiles define a bootstrap task, run: mise run bootstrap"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold "  🥳 Setup complete 🥳 "
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ "$SKIP_DOTFILES" == true ]]; then
  echo "  Next steps:"
  echo ""
  echo "  1. Apply your dotfiles:"
  echo "     chezmoi init --apply <your-dotfiles-repo>"
  echo ""
  echo "  2. Install tools declared in your config:"
  echo "     mise install"
  echo ""
  echo "  3. Run your bootstrap task graph (if defined):"
  echo "     mise run bootstrap"
else
  echo "  Three manual steps remain:"
  echo ""
  echo "  1. Generate your machine GPG key:"
  echo "     gpg --full-generate-key"
  echo "     gpg --armor --export <KEY_ID>  →  github.com/settings/keys"
  echo "     git config --global user.signingkey <KEY_ID>"
  echo "     pass init <KEY_ID>"
  echo ""
  echo "  2. Store machine credentials in pass:"
  echo "     pass insert infisical/$(hostname)/client-id"
  echo "     pass insert infisical/$(hostname)/client-secret"
  echo ""
  echo "  3. Pair Syncthing with your other machines:"
  echo "     http://localhost:8384  →  Actions  →  Show ID"
  echo ""
  echo "  Verify everything is healthy:"
  echo "     exec zsh && mise run doctor"
fi
echo ""