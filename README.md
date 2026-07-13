# Fuzzy dotfiles

A fuzzy collection of dotfiles and environment bootstrap, managed with [chezmoi](https://www.chezmoi.io/) and orchestrated by [mise](https://mise.jdx.dev/).

One command. Blank machine to full working environment.

```sh
curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash
```

> 🐻 **"Just the bear necessities, those simple developer remedies, that make you forget about your worries and your strife... Whatever you are building, to wherever you roam, everything that a bear would need — fully declared and versioned, ready every time you come home... That's why a bear can rest at ease, with all the tools I need, and just enjoy the fuzzy way of life."**

> **Platform scope:** WSL Ubuntu (current LTS/latest) is the primary target, with Lima VMs covering macOS hosts and **Ubuntu containers supported as ephemeral environments** (bootstrap-tested via WSL Containers / `wslc`). The shell layer (starship, fzf-tab, zoxide, atuin, mise, chezmoi) is fully portable. The system bootstrap (apt, pinentry, wslu, systemd) is Ubuntu-specific.

---

## Philosophy — the Systems Operating Experience

FuzzyOS is built as a **forever game**: an environment constructed to compound over years, not to be rebuilt every time a laptop dies. A few principles carry all of it:

**Every layer owns exactly one concern.** apt owns what must exist before mise exists. mise owns every tool and the task graph. chezmoi owns `~`. pass owns machine credentials. No layer reaches into another's domain — when something breaks, you know immediately whose job it is. The seams are explicit and intentional.

**The repo is the source of truth; everything else is a projection.** The home directory is a render of the chezmoi source. GitHub's label UI is a render of `gh-labels.toml`. The prompt, the completions, the systemd units — all derived, all reproducible, none authoritative. If you're editing the projection instead of the source, you're doing it wrong (see the golden rule below).

**The bootstrap is a falsifiable claim, not a hope.** "One command, blank machine to working environment" is only true if something continuously proves it. The `Containerfile` in this repo executes the full bootstrap from a bare image on every build — the claim is re-verified or loudly falsified, never assumed.

**Environments announce themselves.** Platform detection (WSL / Lima / container) selects which profile renders, which tasks run, and which packages install. The prompt itself badges the OS (🐻) and container state (📦) so you always know where you're standing.

---

## Usage

`setup.sh` is designed to be reusable. It takes your dotfiles repo as an argument, or can run bare if you want to bring your own.

```sh
# Default — applies aFuzzyBear dotfiles (fuzzybook machines)
curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash

# With your own chezmoi-compatible dotfiles repo
curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash -s -- \
  --dotfiles https://github.com/yourname/dotfiles.git

# Bare — mise + tools only, apply dotfiles yourself later
curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash -s -- \
  --no-dotfiles
```

> **Minimal images (bare containers):** install the prerequisites first —
> `apt update && apt install -y curl ca-certificates` — then run the one-liner.
> In containers, setup.sh skips GitHub auth and SSH key generation (ephemeral
> environments shouldn't hold machine credentials); run `gh auth login`
> afterwards if you need it.

The `--no-dotfiles` mode gives you a clean mise + gh + SSH key foundation. From there:

```sh
chezmoi init --apply <your-repo>   # apply your dotfiles
mise install                        # install tools declared in config.toml
mise run bootstrap                  # run your task graph (if defined)
```

---

## Containers

FuzzyOS builds and runs as an OCI image. The `Containerfile` at the repo root executes the curl bootstrap non-interactively against a bare Ubuntu image — it is both the image build **and** the standing clean-boot regression test.

```sh
# Build — re-proves the bootstrap from zero every time
wslc build -t fuzzyos .

# Run — a full FuzzyOS shell in seconds, no bootstrap wait
wslc run --rm -it fuzzyos
```

(Any OCI-compatible engine works — `wslc`, docker, podman.)

Container behaviour, by design:

- `FUZZYOS_CONTAINER=1` is set by the Containerfile — build sandboxes don't always plant `/.dockerenv`, so detection honours the env var first, filesystem signals second.
- GitHub auth and SSH key generation are **skipped** — containers are ephemeral and shouldn't mint or hold machine credentials.
- Interactive bootstrap steps (`bootstrap:git`, `bootstrap:atuin`) run only when a real tty is present; builds skip them with instructions for later.
- Host-interop and machine-level services (wslu, syncthing, GPG agent config) are excluded — there is no host to interop with and no daemon lifecycle to own.

---

## How it operates

Every layer owns exactly one concern and respects the boundary of the layers around it.

| Layer | Tool | Owns |
|---|---|---|
| Bootstrap | `setup.sh` | Irreducible preamble — apt, mise, chezmoi apply, hands off |
| Dotfiles | [chezmoi](https://www.chezmoi.io/) | Source of truth for `~` — bridges the git repo to the filesystem |
| Toolchain | [mise](https://mise.jdx.dev/) | Every runtime and CLI tool at the right version, plus the task graph |
| Secrets | [pass](https://www.passwordstore.org/) | Machine-level credentials — Infisical client IDs, API keys, tokens |
| Project secrets | [varlock](https://varlock.dev/) + [Infisical](https://infisical.com/) | Runtime secret injection per project |
| File sync | [Syncthing](https://syncthing.net/) | P2P file transport between WSL machines — no cloud middleman |
| Shell history | [Atuin](https://atuin.sh/) | Encrypted, synced, survives distro nukes |

---

## Bootstrap flow

```
setup.sh
│
├── platform      detect WSL / Lima / container — selects profile, packages, tasks
├── apt           base packages (zsh, gpg, pass, pinentry, …)
│                 + wslu (WSL/Lima only) + syncthing (WSL machines only)
├── gh            GitHub auth + SSH key generation   (skipped in containers)
├── mise          tool manager — the last thing installed manually
├── chezmoi       init --apply → materialises ~/.config/mise/config.toml
├── mise install  all tools declared in config.toml
└── mise run bootstrap
    ├── bootstrap:dotfiles      verify chezmoi managed files landed
    ├── bootstrap:shell         set zsh default, create ~/.zsh/ structure
    ├── bootstrap:identity      set FuzzyOS identity in /etc/os-release
    ├── bootstrap:plugins       clone fzf-tab, autosuggestions, syntax-highlighting
    ├── bootstrap:completions   generate completions for all tools
    ├── bootstrap:gpg           restart gpg-agent with pinentry config   (WSL only)
    ├── bootstrap:syncthing     ~/sync/ structure, ~/dev symlink, systemd (WSL only)
    ├── bootstrap:git           interactive — prompts for identity        (tty only)
    └── bootstrap:atuin         interactive — register / login / skip     (tty only)
```

The graph is profile-aware: container renders drop the WSL-only tasks entirely, and the interactive steps are gated behind a functional tty probe so non-interactive builds run clean end to end.

After `setup.sh` completes on a **machine** (not a container), three manual steps remain — all machine-specific and intentionally not automated:

1. **GPG key** — one per machine, clear provenance
2. **pass store** — machine credentials, GPG-encrypted
3. **Syncthing pairing** — device-to-device, no automation possible

---

## The golden rule

**`~` is read-only. The chezmoi source directory is where you write.**

```sh
# Wrong — changes get overwritten on next chezmoi apply
vim ~/.zshrc
cat > ~/.zsh/conf.d/40-aliases.zsh << 'EOF' ...

# Right
czedit ~/.zshrc                  # edit in source, applies on save
czcd && vim dot_zsh/conf.d/...   # or write directly in source
czap                             # apply source → home
```

Check before touching anything:

```sh
chezmoi managed    # everything chezmoi knows about
chezmoi diff       # what would change if you ran apply right now
```

---

## Day-to-day

```sh
czap               # apply source → home
czedit ~/.zshrc    # edit a managed file, applies on save
czcd               # jump into the git repo
czdiff             # preview changes before applying
czst               # status — what's changed locally vs source

mise run doctor    # verify environment health — run this any time something feels off
mise run update    # update all tools, dotfiles, plugins, regenerate completions
mise tasks         # list all available tasks
```

**Adding a new conf.d file:**

```sh
# Write directly into chezmoi source — never into ~/.zsh/conf.d/ directly
cat > ~/.local/share/chezmoi/dot_zsh/conf.d/60-something.zsh << 'EOF'
# your content
EOF

czap                          # materialise to ~
exec zsh                      # reload shell — always exec zsh, never source
czcd && git add . && git commit -m "feat: ..." && git push
```

> **`exec zsh` not `source ~/.zshrc`** — `source` layers on top of the current session and leaves stale aliases, functions, and variables in memory. `exec zsh` replaces the process entirely. Always use `exec zsh` after config changes.

---

## Shell config structure

Numbered files under `~/.zsh/conf.d/` — explicit load order, single responsibility per file. Adding new behaviour means adding a new numbered file. `.zshrc` never changes.

```
~/.zshrc                       # entry point — loads conf.d, VSCode integration
~/.zsh/conf.d/
  00-general.zsh               # compinit, emacs keybindings, GPG_TTY
  01-history.zsh               # history settings
  02-keybindings.zsh           # key bindings
  10-tools.zsh                 # mise, starship, fzf, zoxide, atuin inits
  20-completion.zsh            # compinit, fzf-tab behaviour, zstyle config
  30-plugins.zsh               # fzf-tab, autosuggestions, syntax-highlighting
  40-aliases.zsh               # shell aliases
  50-functions.zsh             # shell functions
  60-exports.zsh               # environment exports (templated per platform)
~/.zsh/mise-preview.sh         # mise task preview script for fzf-tab
~/.config/mise/
  config.toml                  # global tools + task graph
~/.config/starship.toml        # prompt — plain-text symbols, no font dependency
~/.gnupg/gpg-agent.conf        # pinentry, 8hr / 24hr cache TTL (WSL)
~/.password-store/             # pass store — GPG encrypted, NOT committed
```

> **Load order is load-bearing:** completion setup (20) must run before plugins (30) — fzf-tab and the self-registering completion scripts require compinit to have run first.

> **Never mix aliases and functions with the same name in zsh.** Aliases go in `40-aliases.zsh`, functions go in `50-functions.zsh`. If a function and alias share a name, zsh refuses to define the function and `source ~/.zshrc` won't fix it — only `exec zsh` clears the stale state.

The conf.d loader uses `(N)` — zsh's null glob qualifier. Load-bearing detail:

```sh
for f in ~/.zsh/conf.d/*.zsh(N); do source "$f"; done
```

Without `(N)`, an empty `conf.d/` during bootstrap throws an error and breaks the shell entirely.

---

## Prompt

Starship with **plain-text symbols throughout** — no Nerd Font dependency, so the prompt renders correctly in any terminal, any host, any container. The two glyphs that matter are emoji (dependency-free everywhere):

- 🐻 — the OS badge (FuzzyOS wears the bear)
- 📦 — container badge, rendered only when running inside a container

Dormant modules for future toolchains (terraform, kubernetes, and the whole language zoo) are pre-configured in `starship.toml`; activating one is a single `$module` addition to the format line.

---

## mise task graph

The operational interface for the environment. All bootstrap logic lives here — named, documented, dependency-ordered, re-runnable.

```sh
mise tasks                       # list everything
mise run bootstrap               # full setup — safe to re-run
mise run bootstrap:plugins       # re-clone zsh plugins
mise run bootstrap:completions   # regenerate all shell completions
mise run bootstrap:syncthing     # re-run Syncthing setup (WSL)
mise run bootstrap:git           # reconfigure git identity (interactive)
mise run doctor                  # full health check across all layers
mise run update                  # update tools + dotfiles + plugins + completions
```

A `gh:*` task suite (issue graphs, sprint topo-sort, drift checking, conventional commits) lives under `~/.config/mise/tasks/gh/` — design notes in [`docs/gh-suite-design.md`](docs/gh-suite-design.md).

---

## pass — credential store

Machine-level credentials are GPG-encrypted at rest, one file per secret.

```sh
pass init <KEY_ID>                               # initialise against machine GPG key
pass insert infisical/$(hostname)/client-id
pass insert infisical/$(hostname)/client-secret

# Retrieve at runtime
INFISICAL_CLIENT_ID=$(pass infisical/$(hostname)/client-id) \
INFISICAL_CLIENT_SECRET=$(pass infisical/$(hostname)/client-secret) \
varlock run -- <command>
```

Naming convention: `service/machine/key` — provenance is unambiguous across machines.

`~/.password-store/` is **not committed** to this repo. Each machine initialises its own store against its own GPG key.

---

## Machines

Each machine gets its own GPG key — commit provenance is unambiguous and a compromised key on one machine doesn't affect the others. Containers deliberately get none.

| Machine | Distro | GPG Key |
|---|---|---|
| fuzzybook | Ubuntu WSL2 | `FB7AC461E5E50DEC` |

---

## Further reading

- [`docs/runbook.md`](docs/runbook.md) — the original manual bootstrap runbook; the historical record of what `setup.sh` automates
- [`docs/gh-suite-design.md`](docs/gh-suite-design.md) — design decisions behind the `gh:*` task suite
- [`docs/lima-template.yaml`](docs/lima-template.yaml) — Lima VM template for macOS hosts