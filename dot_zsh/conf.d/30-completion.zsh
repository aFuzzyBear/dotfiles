# ── Completion paths ──────────────────────────────────────────────────────────
# User completions first (so they override system ones)
fpath=(~/.zsh/completions $fpath)

# ── System completion paths ───────────────────────────────────────────────────
# Ensure Zsh's built‑in completion functions are available.

# Linux (Debian/Ubuntu/Arch/etc.)
if [[ -d /usr/share/zsh/functions/Completion ]]; then
  fpath+=(
    /usr/share/zsh/functions/Completion/Base
    /usr/share/zsh/functions/Completion/Linux
    /usr/share/zsh/functions/Completion/Zsh
  )
fi

# macOS (Homebrew)
# if [[ -d /opt/homebrew/share/zsh/site-functions ]]; then
#   fpath+=(/opt/homebrew/share/zsh/site-functions)
# fi

# ── Tool completions (pnpm, npm, mise, docker, compose) ───────────────────────
# Generate/update completion files silently and idempotently.

_completion_dir="$HOME/.zsh/completions"
mkdir -p "$_completion_dir"

# pnpm
if command -v pnpm >/dev/null 2>&1; then
  pnpm completion zsh > "$_completion_dir/_pnpm" 2>/dev/null
fi

# npm
if command -v npm >/dev/null 2>&1; then
  npm completion > "$_completion_dir/_npm" 2>/dev/null
fi

# mise
if command -v mise >/dev/null 2>&1; then
  mise completion zsh > "$_completion_dir/_mise" 2>/dev/null
fi

# docker + compose
if command -v docker >/dev/null 2>&1; then
  docker completion zsh > "$_completion_dir/_docker" 2>/dev/null
  docker compose completion zsh > "$_completion_dir/_docker-compose" 2>/dev/null
fi

# ── Init ──────────────────────────────────────────────────────────────────────
autoload -Uz compinit

# Only rebuild the completion dump once per day
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C  # skip security check on subsequent loads (fast path)
fi

# ── Core behaviour ────────────────────────────────────────────────────────────
zstyle ':completion:*' menu no                        # let fzf-tab take over
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # colour completions
zstyle ':completion:*:descriptions' format '[%d]'     # group labels
zstyle ':completion:*:git-checkout:*' sort false      # keep git branch order
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'   # case-insensitive match

# ── fzf-tab behaviour ─────────────────────────────────────────────────────────
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-flags '--height=50%' '--layout=reverse' '--info=inline'

# Fix: stop fzf-tab pre-filling the last completed word into the fzf query.
zstyle ':fzf-tab:*' query-string prefix

# ── Previews ──────────────────────────────────────────────────────────────────
# cd preview
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
  'eza --color=always --icons --group-directories-first $realpath 2>/dev/null || ls --color $realpath'

# mise task preview — external script to avoid inline quote escaping hell
zstyle ':fzf-tab:complete:mise:*' fzf-preview \
  'bash ~/.zsh/mise-preview.sh "$word"'