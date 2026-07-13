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
      00-general.zsh
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
  00-general.zsh               # compinit, emacs keybindings, GPG_TTY
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


---

## Container Support — Changes, Issues & Rationale (12 July 2026)

> **Context:** WSL Containers (`wslc`, Windows public preview) landed on fuzzybook.
> Weekend exercise, deliberately scoped: prove the curl bootstrap works from a bare
> OCI image, produce a throwaway `Containerfile`, and park everything architectural
> for the chezmoi-retirement audit. Result: the first FuzzyOS image, built via
> `wslc build`, running the full bootstrap non-interactively end to end.
>
> The `Containerfile` at the repo root is now the **standing clean-boot regression
> test** — every build re-executes setup.sh from zero. Before this, "one command,
> blank machine to working environment" had no automated proof.

### Decisions

| Decision | Rationale |
|---|---|
| Containers skip GitHub auth + SSH key generation | Ephemeral environments shouldn't mint or hold machine credentials. Also: each pre-gate test run uploaded an orphaned SSH key to the GitHub account, titled after a random container hostname. Machine identity is for machines. |
| `FUZZYOS_CONTAINER=1` set by the Containerfile; detection is env-var-first | `wslc build` RUN steps do **not** plant `/.dockerenv` (interactive `wslc run` does — verified 12 Jul). Filesystem signals are unreliable in build sandboxes; an explicit env var is deterministic. Both `setup.sh` `is_container()` and the chezmoi template honour it, filesystem checks as fallback. Mirrors the existing `LIMA_VM=1` pattern in the Lima template. |
| Container profile beats WSL profile in the chezmoi template | Containers on the WSL2 kernel match the `microsoft` string in `/proc/version` — the kernel identifies the **host**, not the environment. Without container-first precedence, the WSL profile renders inside wslc containers and the task graph includes gpg/syncthing tasks that require systemd. |
| `setup.sh` PLATFORM elif order left **unchanged** (wsl before container) | Flipping it is correct but changes behaviour; the template already applies the correct precedence, and `is_container()` is called directly to gate the steps that matter. Script and template now deliberately disagree about PLATFORM in containers — documented divergence, owned by the audit. |
| wslu excluded from containers; syncthing scoped to WSL machines only | wslu is host-interop (URL opening) — meaningless in a container and not packaged on every base image (build broke on it). syncthing's own bootstrap task was already `isWSL`-gated; apt was installing a daemon nothing would configure. Lima loses syncthing as a consequence — flagged to Gabe. |
| Base image pinned to `ubuntu:latest` | Deliberate choice to track current Ubuntu rather than a fixed LTS. Trade-off acknowledged: `latest` retags are silent distro migrations. Revisit at the audit if reproducibility wins. |
| Interactive bootstrap steps gated behind a functional tty probe | `bootstrap:git` / `bootstrap:atuin` read from `/dev/tty`. Builds have no terminal. Probe must *attempt the open* — see gotcha below. |

### Issues encountered (in discovery order)

**`sudo: command not found` — setup.sh line 119**
- *Symptom:* bootstrap dies at "Installing base packages" in a bare container.
- *Root cause:* minimal images run as root with no sudo installed; every `sudo` call (setup.sh **and** the mise task graph — `usermod`, `sed`) assumes it exists.
- *Fix:* guard at the top of §1 — if uid 0 and no sudo, `apt install sudo`. sudo-as-root is a passthrough, so all downstream calls work unmodified. Chosen over a `$SUDO` variable idiom to avoid touching two files.

**tzdata interactive prompt during apt install**
- *Symptom:* build/bootstrap stops to ask for a geographic area.
- *Root cause:* debconf goes interactive when tzdata arrives as a dependency; container images aren't preseeded the way WSL/Lima images are.
- *Fix:* `export DEBIAN_FRONTEND=noninteractive` when `is_container`.

**`Unable to locate package wslu`**
- *Symptom:* apt fails on wslu in a container.
- *Root cause:* host-interop package, not present/needed in container archives.
- *Fix:* package gating (see Decisions).

**chezmoi template crash: `systemd-detect-virt: executable file not found`**
- *Symptom:* `chezmoi init --apply` dies rendering `.chezmoi.toml.tmpl`.
- *Root cause:* the Lima check shelled out via `output "systemd-detect-virt"` unconditionally. WSL distros and Lima VMs ship systemd, so the missing-binary case was invisible until the first environment without it (bare OCI image). chezmoi's `output` fails hard where bash's `$( ) 2>/dev/null` fails soft — same detection logic, different failure mode.
- *Fix:* `lookPath` guard; `$virt` defaults empty. Hostname check short-circuits first on real Lima.

**`bootstrap:shell` crash: `USER: unbound variable`**
- *Symptom:* task graph dies at line 8 of bootstrap:shell.
- *Root cause:* containers don't populate `$USER` (set by login; nothing logged in); tasks run `set -u`.
- *Fix:* `id -un` — ask the kernel, don't trust the env. Correct everywhere.

**Build crash at `clear`: `TERM environment variable not set`**
- *Symptom:* build dies immediately after "Platform detected".
- *Root cause:* `clear` exits nonzero with no TERM; `set -e` promotes cosmetics to fatality.
- *Fix:* `if [[ -t 1 && -n "${TERM:-}" ]]; then clear; fi` — as an `if`, so the false branch can't itself trip `set -e`.

**Wrong profile rendered in `wslc build` (gpg/syncthing tasks ran, `systemctl: command not found`)**
- *Symptom:* build reaches the task graph but runs WSL-only tasks.
- *Root cause:* `/.dockerenv` absent in build sandboxes → template's container check failed → `isWSL` won via kernel string.
- *Fix:* template honours `FUZZYOS_CONTAINER` (see Decisions). This bug is the proof the env var is necessary, not paranoia.

**`/dev/tty: No such device or address` at bootstrap:git**
- *Symptom:* build completes the bootstrap banner then dies on the interactive step.
- *Root cause:* `[[ -e /dev/tty && -r /dev/tty ]]` passed — the node **exists** in the build sandbox — but nothing is behind it, so the redirect fails at open time.
- *Fix:* functional probe: `if (exec < /dev/tty) 2>/dev/null; then …` — attempt the open in a throwaway subshell instead of inspecting the node. File-test guards lie in sandboxes; only the operation itself tells the truth.

**`bootstrap:completions` assumes docker exists**
- *Symptom:* two `docker: command not found` lines (non-fatal).
- *Fix:* `command -v docker` guard around docker/docker-compose completion generation.

### Known-stale items surfaced by this work (owned by the audit)


- Bootstrap banner echoes GPG/pass steps unconditionally (needs the same `isWSL` gating the tasks got) and prints a duplicate "Remaining manual steps" header in containers. Cosmetic.
- Platform detection exists in two implementations (setup.sh functions, chezmoi template) that now deliberately disagree about PLATFORM in containers. Env-var signals exist in two flavours (`FUZZYOS_CONTAINER`, `LIMA_VM`) invented independently. Unify at the audit — setup.sh computes the answer first and could pass it down.
- `--ci` / non-interactive flag for setup.sh would formalise what the tty probe does ad hoc.
- `mise oci build` (experimental) implements per-tool OCI layering, apt package layers, and dotfile baking upstream — candidate to replace significant custom machinery. Audit exhibit A. Distinct purpose from the Containerfile, which exists to *test the curl bootstrap*, not to package the environment.