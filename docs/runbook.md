# WSL Ubuntu 24.04 — Fresh Distro Runbook

> **Machine:** fuzzybook · **Distro:** Ubuntu-24.04 · **User:** fuzzy  
> **Kernel:** `6.6.87.2-microsoft-standard-WSL2`  
> **Dotfiles:** `https://github.com/aFuzzyBear/dotfiles`

This runbook documents the full process of bootstrapping a fresh WSL Ubuntu 24.04 distro into a complete, reproducible dev environment. It exists so the process is never tribal knowledge again.

**Ownership model — read this first:**

| Layer | Tool | Owns |
|---|---|---|
| Dotfiles | chezmoi | Source of truth for `~` |
| Toolchain | mise | Every runtime and CLI tool + task graph |
| Secrets | pass | Machine-level credentials |
| Project secrets | varlock + Infisical | Runtime secret injection per project |
| File sync | Syncthing | P2P transport between machines |
| Shell history | Atuin | Encrypted, synced history |

---

## Phase 1 — Base System

### 1.1 Install distro
```powershell
# From Windows PowerShell
wsl --list --online             # verify Ubuntu-24.04 is available
wsl --install Ubuntu-24.04      # install + provision
# Create user: fuzzy
```

### 1.2 Restart WSL
```powershell
# Required after initial provisioning
wsl --shutdown
# Relaunch: wsl -d Ubuntu-24.04
```

### 1.3 Update base packages
```sh
cd ~
sudo apt update && sudo apt full-upgrade -y
```

### 1.4 Install essential apt packages
> Only things mise cannot manage go here. Runtimes and CLI tools are declared in `~/.config/mise/config.toml`.

```sh
sudo apt install -y \
  curl \            # mise install + general fetching
  git \             # chezmoi, plugin clones, everything
  zsh \             # target shell
  gpg \             # commit signing + pass encryption
  unzip \           # archive extraction
  jq \              # JSON processing (mise previews, ready_cmd etc)
  build-essential \ # gcc/make — native addons, building from source
  ca-certificates \ # TLS root certs
  wslu \            # WSL utilities — wslview opens URLs in Windows browser
  pinentry-gtk-2 \  # GPG passphrase GUI (WSL has no TTY pinentry by default)
  syncthing \       # P2P file sync
  pass \            # GPG-encrypted credential store
  bat \             # better cat
  fd-find \         # better find
  ripgrep \         # better grep
  btop              # better top
```

> ⚠️ Ubuntu ships `bat` as `batcat` and `fd` as `fdfind` — symlink them:
> ```sh
> mkdir -p ~/.local/bin
> ln -sf /usr/bin/batcat ~/.local/bin/bat
> ln -sf /usr/bin/fdfind ~/.local/bin/fd
> ```

---

## Phase 2 — GitHub & SSH

### 2.1 Install gh CLI
```sh
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
  https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update -q && sudo apt install -y gh
```

### 2.2 Authenticate with GitHub
```sh
gh auth login --web -h github.com
# → GitHub.com → HTTPS → Login with a web browser
# wslu handles opening the browser from WSL
```

### 2.3 Generate SSH key
```sh
ssh-keygen -t ed25519 -C "$(gh api user --jq .email)" -f ~/.ssh/id_ed25519 -N ""
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
gh ssh-key add ~/.ssh/id_ed25519.pub --title "$(hostname)-wsl-$(date +%Y%m%d)"
```

---

## Phase 3 — GPG & Git

### 3.1 Generate machine GPG key
```sh
gpg --full-generate-key
# Type: 1 (RSA and RSA)
# Size: 4096
# Expiry: 0 (no expiry)
# Name: Fuzzy Bear
# Email: 28299972+aFuzzyBear@users.noreply.github.com
# Comment: git signing key for <machinename>  ← identifies which machine
```

### 3.2 Configure GPG pinentry (WSL fix)
> Without this, signed commits silently fail — WSL has no TTY pinentry by default.

```sh
cat > ~/.gnupg/gpg-agent.conf << 'EOF'
pinentry-program /usr/bin/pinentry-gtk-2
default-cache-ttl 28800
max-cache-ttl 86400
EOF
gpgconf --kill gpg-agent
```
> `default-cache-ttl 28800` = 8 hours · `max-cache-ttl 86400` = 24 hours

### 3.3 Add public key to GitHub
```sh
gpg --list-secret-keys                          # note your KEY_ID
gpg --armor --export <KEY_ID>                   # copy full output
```
**GitHub → Settings → SSH and GPG keys → New GPG key**  
Title format: `<MachineName> Ubuntu 24.04 LTS`

### 3.4 Configure git globals
```sh
git config --global user.name "Fuzzy Bear"
git config --global user.email "28299972+aFuzzyBear@users.noreply.github.com"
git config --global user.signingkey <KEY_ID>
git config --global commit.gpgsign true
git config --global gpg.program gpg
git config --global init.defaultbranch main
```

---

## Phase 4 — mise

### 4.1 Install mise
```sh
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
source ~/.bashrc
mise --version  # verify
```

### 4.2 Install chezmoi via mise
```sh
mise use -g chezmoi
mise reshim
chezmoi --version  # verify
```

---

## Phase 5 — chezmoi & Dotfiles

### 5.1 Init chezmoi against dotfiles repo
```sh
# HTTPS — SSH keys exist now but chezmoi init is simpler over HTTPS
chezmoi init --apply https://github.com/aFuzzyBear/dotfiles.git
```
This materialises everything in `~` — zsh config, mise config, starship, gpg-agent.conf, all of it.

### 5.2 chezmoi golden rule
**`~` is read-only. The chezmoi source directory is where you write.**

```sh
# Check if a file is managed before touching it
chezmoi managed

# Edit a managed file (applies on save)
czedit ~/.zshrc

# Write a new conf.d file
cat > ~/.local/share/chezmoi/dot_zsh/conf.d/40-aliases.zsh << 'EOF'
# content here
EOF
czap  # apply to ~

# Commit and push
czcd
git add . && git commit -m "feat: ..." && git push
```

### 5.3 chezmoi source structure
```
~/.local/share/chezmoi/
  dot_zshrc
  dot_zsh/
    conf.d/
      00-core.zsh
      10-tools.zsh
      20-plugins.zsh
      30-completion.zsh
      40-aliases.zsh
    executable_mise-preview.sh
  dot_config/
    starship.toml
    mise/
      config.toml       # global tools + task_dirs
      env.toml          # machine-level env (non-secret)
      tasks/
        bootstrap.toml  # full bootstrap task graph
  private_dot_gnupg/
    gpg-agent.conf
  .chezmoiignore
  README.md
  bootstrap.sh
```

---

## Phase 6 — mise Tools & Task Graph

### 6.1 Install global tools
```sh
# Tool versions declared in ~/.config/mise/config.toml (now materialised by chezmoi)
mise install
mise reshim
mise ls  # verify all tools present
```

### 6.2 Run bootstrap task graph
```sh
# Hands off to mise for everything it can own:
# - zsh plugin clones
# - shell completion generation
# - Syncthing folder structure + systemd service
mise run bootstrap
```

### 6.3 Available tasks
```sh
mise tasks                       # list all tasks
mise run bootstrap               # full setup — safe to re-run
mise run bootstrap:plugins       # clone/update zsh plugins
mise run bootstrap:completions   # regenerate shell completions
mise run bootstrap:syncthing     # Syncthing folder + service setup
```

---

## Phase 7 — zsh

### 7.1 Set zsh as default shell
```sh
chsh -s $(which zsh)
# Launch immediately: exec zsh
# On first launch hit 0 — creates blank .zshrc (chezmoi owns the real one)
```

### 7.2 Shell config structure
```
~/.zshrc                    # entry point — loads conf.d, VSCode integration
~/.zsh/conf.d/
  00-core.zsh               # compinit, emacs keybindings, GPG_TTY
  10-tools.zsh              # mise, starship, fzf, zoxide, atuin inits
  20-plugins.zsh            # fzf-tab, autosuggestions, syntax-highlighting
  30-completion.zsh         # fzf-tab behaviour, zstyle config
  40-aliases.zsh            # shell aliases
~/.zsh/plugins/             # third-party plugin clones (not chezmoi managed)
~/.zsh/completions/         # generated completions
~/.zsh/mise-preview.sh      # mise task fzf-tab preview
```

> **Key detail:** The conf.d loader uses `(N)` — zsh's null glob qualifier. Without it an empty conf.d during bootstrap throws an error and breaks the shell:
> ```sh
> for f in ~/.zsh/conf.d/*.zsh(N); do source "$f"; done
> ```

---

## Phase 8 — VSCode

### 8.1 Connect to distro
```sh
# From inside WSL
code .
# VSCode installs its server automatically on first run
```

### 8.2 User settings.json
```json
{
  "terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono",
  "terminal.integrated.defaultProfile.linux": "zsh",
  "terminal.integrated.profiles.linux": {
    "zsh": { "path": "/usr/bin/zsh" }
  }
}
```

### 8.3 Fonts (Windows side)
> VSCode on WSL renders fonts through Windows — install on Windows, not Linux.

1. Download **JetBrainsMono Nerd Font** from [nerdfonts.com](https://www.nerdfonts.com/font-downloads)
2. Unzip → select all `.ttf` → right click → **Install for all users**
3. Full restart VSCode (not just reload window)

---

## Phase 9 — pass (Credential Store)

```sh
# Initialise store against this machine's GPG key
pass init <KEY_ID>

# Store machine credentials
pass insert infisical/<hostname>/client-id
pass insert infisical/<hostname>/client-secret

# Retrieve at runtime (e.g. for varlock)
INFISICAL_CLIENT_ID=$(pass infisical/$(hostname)/client-id) \
INFISICAL_CLIENT_SECRET=$(pass infisical/$(hostname)/client-secret) \
varlock run -- <command>
```

> Naming convention: `service/machine/key` — provenance is unambiguous across machines.  
> `~/.password-store/` is GPG-encrypted and **not committed** to the dotfiles repo.

---

## Phase 10 — Atuin (Shell History)

```sh
atuin register   # new account
# or
atuin login      # existing account

atuin sync
```

`ctrl+r` opens the Atuin TUI — searchable by host, directory, exit code, duration.

---

## Phase 11 — Syncthing

> Handled by `mise run bootstrap:syncthing` — this section covers the manual GUI steps.

### 11.1 First run
```sh
# Already started as a systemd service by the bootstrap task
systemctl --user status syncthing  # verify active
```

### 11.2 GUI setup
Open `http://127.0.0.1:8384`

1. **Set GUI password** — Actions → Settings → GUI
2. **Remove Default Folder**
3. **Add Folder:** label `sync`, path `~/sync`, type Send & Receive
4. **Add remote device** — enter device ID from other machine

### 11.3 Directory structure
```sh
# Created by mise run bootstrap:syncthing
~/sync/           # Syncthing root
~/sync/dev/       # your dev projects
~/sync/scratch/   # throwaway work
~/dev             # symlink → ~/sync/dev (preserves muscle memory)
~/sync/.stignore  # excludes node_modules, build artifacts, secrets
```

---

## Known Issues & Gotchas

### Syncthing database lock on fresh bootstrap

**Symptom:** `syncthing.service` fails with exit-code 1 immediately after `mise run bootstrap`. `journalctl --user -u syncthing` shows:

```
WARNING: Error opening database: resource temporarily unavailable
(is another instance of Syncthing running?)
```

**Root cause:** Two compounding issues:

1. Running `syncthing --no-browser` manually during initial config generation leaves an orphaned process holding a database lock. When the systemd service subsequently tries to start, it hits the locked database and enters a tight crash loop until systemd marks it as failed.

2. Adding `aqua:syncthing/syncthing` to `~/.config/mise/config.toml` creates a second mise-managed binary alongside the apt-installed `/usr/bin/syncthing`. The systemd service unit hardcodes `/usr/bin/syncthing` — it has no knowledge of the mise binary. Two owners for the same tool violates the ownership model and can produce version conflicts.

**Fix:**

```sh
# Kill orphaned process and clear lock files
pkill -x syncthing || true
find ~/.local/state/syncthing ~/.config/syncthing -name "*.lock" -delete 2>/dev/null || true

# Restart cleanly via the task
mise run syncthing:restart
```

**Prevention:**

- Never run `syncthing --no-browser` manually on a machine where systemd will own the service. Let `bootstrap:syncthing` handle first-run setup — it kills orphaned processes before enabling the service.
- `aqua:syncthing/syncthing` must not appear in `config.toml`. apt owns syncthing, systemd owns the service lifecycle. The comment in `config.toml` documents this explicitly.

**Housekeeping tasks:**

```sh
mise run syncthing:status    # check service status and recent logs
mise run syncthing:restart   # safe restart — handles orphaned processes and lock files
```

| Machine | Distro | GPG Key |
|---|---|---|
| fuzzybook | Ubuntu 24.04 LTS WSL2 | `FB7AC461E5E50DEC` |