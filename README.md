# Fuzzy dotfiles

A fuzzy collection of dotfiles and environment bootstrap for WSL Ubuntu, managed with [chezmoi](https://www.chezmoi.io/).

One command. Blank machine to full working environment.

```sh
curl -sSL https://raw.githubusercontent.com/aFuzzyBear/dotfiles/main/setup.sh | bash
```

> 🐻 **“Just the bear necessities,those simple developer remedies, That make you forgot about your worries and your strife...Whatever you are buildinging, to wherever you roam,Everything that a bear would need, fully declared and versioned, ready everytime you come home... Thats why a bear can rest at ease, with all the tools I need, and just enjoy the fuzzy way of life.”**

> **Platform scope:** WSL Ubuntu 24.04 LTS. The shell layer (starship, fzf-tab, zoxide, atuin, mise, chezmoi) is fully portable and runs on macOS unchanged. The system bootstrap (apt, pinentry-gtk2, wslu, systemd) is Ubuntu-specific and would need a Darwin branch. Known future direction — contributions welcome.

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

The `--no-dotfiles` mode gives you a clean mise + gh + SSH key foundation. From there:

```sh
chezmoi init --apply <your-repo>   # apply your dotfiles
mise install                        # install tools declared in config.toml
mise run bootstrap                  # run your task graph (if defined)
```

---

## How it operates

Every layer owns exactly one concern and respects the boundary of the layers around it. When something breaks, you know immediately whose job it is.

| Layer | Tool | Owns |
|---|---|---|
| Bootstrap | `setup.sh` | Irreducible preamble — apt, mise, chezmoi apply, hands off |
| Dotfiles | [chezmoi](https://www.chezmoi.io/) | Source of truth for `~` — bridges the git repo to the filesystem |
| Toolchain | [mise](https://mise.jdx.dev/) | Every runtime and CLI tool at the right version, plus the task graph |
| Secrets | [pass](https://www.passwordstore.org/) | Machine-level credentials — Infisical client IDs, API keys, tokens |
| Project secrets | [varlock](https://varlock.dev/) + [Infisical](https://infisical.com/) | Runtime secret injection per project |
| File sync | [Syncthing](https://syncthing.net/) | P2P file transport between machines — no cloud middleman |
| Shell history | [Atuin](https://atuin.sh/) | Encrypted, synced, survives distro nukes |

The principle: no layer reaches into another's domain. `pass` holds credentials, varlock consumes them at runtime. chezmoi materialises config, mise installs tools. The seams are explicit and intentional.

---

## Bootstrap flow

```
setup.sh
│
├── apt           base packages (zsh, gpg, wslu, pinentry-gtk2, pass, syncthing)
├── gh            GitHub auth + SSH key generation
├── mise          tool manager — the last thing installed manually
├── chezmoi       init --apply → materialises ~/.config/mise/config.toml
├── mise install  all tools declared in config.toml
└── mise run bootstrap
    ├── bootstrap:dotfiles      verify chezmoi managed files landed
    ├── bootstrap:git           interactive — prompts for name/email (pre-filled from gh)
    ├── bootstrap:gpg           restart gpg-agent with pinentry config
    ├── bootstrap:shell         set zsh default, create ~/.zsh/ structure
    ├── bootstrap:plugins       clone fzf-tab, autosuggestions, syntax-highlighting
    ├── bootstrap:completions   generate completions for all tools
    ├── bootstrap:syncthing     ~/sync/ structure, ~/dev symlink, systemd service
    └── bootstrap:atuin         interactive — register / login / skip
```

Steps 7 and 8 are graceful — if no `config.toml` or `bootstrap` task exists (e.g. bare mode or a dotfiles repo without a task graph), they warn and continue rather than failing.

After `setup.sh` completes, three manual steps remain — all machine-specific and intentionally not automated:

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
  20-plugins.zsh               # fzf-tab, autosuggestions, syntax-highlighting
  30-completion.zsh            # fzf-tab behaviour, zstyle config
  40-aliases.zsh               # shell aliases
  50-functions.zsh             # shell functions
  90-exports.zsh               # environment exports
~/.zsh/mise-preview.sh         # mise task preview script for fzf-tab
~/.config/mise/
  config.toml                  # global tools + task graph
  env.sh                       # machine-level env (non-secret values only)
~/.config/starship.toml        # prompt layout and styling
~/.gnupg/gpg-agent.conf        # pinentry-gtk2, 8hr / 24hr cache TTL
~/.password-store/             # pass store — GPG encrypted, NOT committed
```

> **Never mix aliases and functions with the same name in zsh.** Aliases go in `40-aliases.zsh`, functions go in `50-functions.zsh`. If a function and alias share a name, zsh refuses to define the function and `source ~/.zshrc` won't fix it — only `exec zsh` clears the stale state.

The conf.d loader uses `(N)` — zsh's null glob qualifier. Load-bearing detail:

```sh
for f in ~/.zsh/conf.d/*.zsh(N); do source "$f"; done
```

Without `(N)`, an empty `conf.d/` during bootstrap throws an error and breaks the shell entirely.

---

## mise task graph

The operational interface for the environment. All bootstrap logic lives here — named, documented, dependency-ordered, re-runnable.

```sh
mise tasks                       # list everything
mise run bootstrap               # full setup — safe to re-run
mise run bootstrap:plugins       # re-clone zsh plugins
mise run bootstrap:completions   # regenerate all shell completions
mise run bootstrap:syncthing     # re-run Syncthing setup
mise run bootstrap:git           # reconfigure git identity (interactive)
mise run doctor                  # full health check across all layers
mise run update                  # update tools + dotfiles + plugins + completions
```

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

Each machine gets its own GPG key — commit provenance is unambiguous and a compromised key on one machine doesn't affect the others.

| Machine | Distro | GPG Key |
|---|---|---|
| fuzzybook | Ubuntu 24.04 LTS WSL2 | `FB7AC461E5E50DEC` |