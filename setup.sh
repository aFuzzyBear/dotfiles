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
#   1. Platform detection  — WSL / Lima / container
#   2. apt base packages   — system-level deps mise cannot manage
#   3. gh CLI              — needed before chezmoi (SSH key upload)
#   4. GitHub auth         — needed before chezmoi (repo access)
#   5. SSH key             — machine identity for git
#   6. mise                — the tool manager itself
#   7. chezmoi             — materialises dotfiles from your repo
#   8. mise install        — tools declared in ~/.config/mise/config.toml
#   9. mise run bootstrap  — hands off to the task graph (if dotfiles provide one)
#
# After this script completes, the mise task graph owns everything.
# To verify environment health: mise run doctor

set -euo pipefail

# ── Colours / helpers ─────────────────────────────────────────────────────────
GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "\n${BLUE}→${NC} $1"; }
ok()    { echo -e "  ${GREEN}✓${NC} $1"; }
warn()  { echo -e "  ${YELLOW}⚠${NC}  $1"; }
bold()  { echo -e "${BOLD}$1${NC}"; }
die()   { echo -e "\n${YELLOW}✗ $1${NC}" >&2; exit 1; }

# ── Platform detection ────────────────────────────────────────────────────────
# Order matters: WSL before container before Lima. A Lima VM with Docker
# installed should NOT be detected as a container — the /.dockerenv check
# guards against that because Lima's PID 1 is systemd, not a container runtime.
is_wsl()       { grep -qi microsoft /proc/version 2>/dev/null; }
is_container() { [ -f /.dockerenv ] || grep -q 'docker\|lxc' /proc/1/cgroup 2>/dev/null; }
is_lima()      { [[ "$(hostname)" == lima-* ]] || [[ "$(systemd-detect-virt 2>/dev/null)" == "apple" ]]; }
is_linux()     { [[ "$(uname -s)" == "Linux" ]]; }

if is_linux; then
  if is_wsl;         then PLATFORM="wsl"
  elif is_container; then PLATFORM="container"
  elif is_lima;      then PLATFORM="lima"
  else
    die "Linux detected but no sub-context matched (not WSL, container, or Lima).
         FuzzyOS does not currently support bare-metal Linux bootstrap.
         Investigate detection logic before proceeding."
  fi
else
  die "Unsupported platform: $(uname -s). FuzzyOS runs on WSL, Lima, or containers."
fi

info "Platform detected: $PLATFORM"

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
echo "  Platform: $PLATFORM"
if [[ "$SKIP_DOTFILES" == true ]]; then
  echo "  Mode: bare environment (no dotfiles)"
else
  echo "  Dotfiles: $DOTFILES_REPO"
fi
echo ""

# ── Sanity checks ─────────────────────────────────────────────────────────────
command -v apt &>/dev/null || die "apt not found — Ubuntu/Debian only"

# ── 1. Base packages ──────────────────────────────────────────────────────────
# apt owns everything here. Rule: if it's needed before `mise install` runs,
# or if it integrates with systemd, apt owns it — not mise.
info "Installing base packages..."
sudo apt update -q
sudo apt upgrade -y -q

# Common to all Linux contexts — including wslu, which we use inside Lima
# for URL-opening interop with the Mac host via the port-forwarding mechanism.
COMMON_PKGS=(
  curl git zsh gpg unzip jq
  build-essential ca-certificates
  wslu
  syncthing
  pass
  bat fd-find ripgrep btop
  bison flex libreadline-dev zlib1g-dev libssl-dev
  pkg-config uuid-dev libossp-uuid-dev
)

# Platform-specific pinentry:
#   WSL:       pinentry-gtk2 — renders graphically via WSLg
#   Lima:      pinentry-curses — headless VM accessed over VSCode Remote SSH,
#              needs in-terminal prompts
#   Container: pinentry-curses — same reason, no display
case "$PLATFORM" in
  wsl)       PLATFORM_PKGS=(pinentry-gtk2) ;;
  lima)      PLATFORM_PKGS=(pinentry-curses) ;;
  container) PLATFORM_PKGS=(pinentry-curses) ;;
esac

sudo apt install -y "${COMMON_PKGS[@]}" "${PLATFORM_PKGS[@]}"
ok "Base packages installed ($PLATFORM variant)"

# Ubuntu ships bat as `batcat` and fd as `fdfind` — normalise to expected names
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
  gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)-${PLATFORM}-$(date +%Y%m%d)"
  ok "SSH key generated and added to GitHub"
else
  ok "SSH key already exists"
fi

# ── 5. mise ───────────────────────────────────────────────────────────────────
if ! command -v mise &>/dev/null; then
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
if mise tasks 2>/dev/null | grep -q "^bootstrap"; then
  info "Running bootstrap task graph..."
  mise run bootstrap

  info "Configuring git identity..."
  mise run bootstrap:git < /dev/tty

  info "Setting up Atuin..."
  mise run bootstrap:atuin < /dev/tty
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
  case "$PLATFORM" in
    wsl)
      echo "  You're running in WSL. Three manual steps remain:"
      echo ""
      echo "  1. Generate your machine GPG key:"
      echo "     gpg --full-generate-key"
      echo "     gpg --armor --export <KEY_ID>  →  github.com/settings/keys"
      echo "     git config --global user.signingkey <KEY_ID>"
      echo "     pass init <KEY_ID>"
      echo ""
      echo "  2. Store machine credentials in pass:"
      echo "     pass insert infisical/client-id"
      echo "     pass insert infisical/client-secret"
      echo ""
      echo "  3. Pair Syncthing with your other machines:"
      echo "     http://localhost:8384  →  Actions  →  Show ID"
      echo ""
      echo "  Verify everything is healthy:"
      echo "     exec zsh && mise run doctor"
      ;;
    lima)
      echo "  You're in a Lima VM — GPG and pass are mounted from your Mac."
      echo ""
      echo "  Verify credential chain works:"
      echo ""
      echo "  1. GPG sees the Mac's keys:"
      echo "     gpg --list-secret-keys"
      echo ""
      echo "  2. pass decrypts:"
      echo "     pass ls"
      echo ""
      echo "  3. Pair Syncthing with your other machines:"
      echo "     http://localhost:8384  →  Actions  →  Show ID"
      echo ""
      echo "  If GPG prompts for passphrase in-terminal, the mount is working"
      echo "  but the Mac's agent hasn't cached — enter it once, it'll stick."
      echo ""
      echo "  If you hit 'no terminal' errors from gpg, add to your shell rc:"
      echo "     export GPG_TTY=\$(tty)"
      echo ""
      echo "  Verify environment health:"
      echo "     exec zsh && mise run doctor"
      ;;
    container)
      echo "  You're in a devcontainer — run: exec zsh && mise run doctor"
      ;;
  esac
fi
echo ""