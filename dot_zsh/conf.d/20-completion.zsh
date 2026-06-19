# ── Completion paths ──────────────────────────────────────────────────────────
# User completions first (so they override system ones)
fpath=(~/.zsh/completions $fpath)

# ── Init ──────────────────────────────────────────────────────────────────────
autoload -Uz compinit

# Only rebuild the completion dump once per day
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C  # skip security check on subsequent loads (fast path)
fi

# ── Core behaviour ────────────────────────────────────────────────────────────
# Let fzf-tab handle menus instead of builtin completion UI
zstyle ':completion:*' menu no

# Colourised completion listings (respects LS_COLORS)
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Group labels for clarity
zstyle ':completion:*:descriptions' format '[%d]'

# Keep git branch order as-is (don’t sort alphabetically)
zstyle ':completion:*:git-checkout:*' sort false

# Case-insensitive matching (Foo == foo)
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# Don’t complete “.” and “..” unless explicitly typed
zstyle ':completion:*' ignore-parents parent pwd

# ── fzf-tab behaviour ─────────────────────────────────────────────────────────
# Switch between preview groups with < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# Consistent fzf layout
zstyle ':fzf-tab:*' fzf-flags \
  '--height=50%' \
  '--layout=reverse' \
  '--info=inline'

# Fix: stop fzf-tab pre-filling the last completed word into the fzf query
zstyle ':fzf-tab:*' query-string prefix

# ── Previews ──────────────────────────────────────────────────────────────────
# cd preview: show directory contents with eza (fallback to ls)
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
  'eza --color=always --icons --group-directories-first $realpath 2>/dev/null || ls --color $realpath'

# mise task preview — external script to avoid inline quote escaping hell
zstyle ':fzf-tab:complete:mise:*' fzf-preview \
  'bash ~/.zsh/mise-preview.sh "$word"'
