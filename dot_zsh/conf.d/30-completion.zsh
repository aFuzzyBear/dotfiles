
# ── Completion paths ──────────────────────────────────────────────────────────
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
zstyle ':completion:*' menu no                        # let fzf-tab take over
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} # colour completions
zstyle ':completion:*:descriptions' format '[%d]'     # group labels
zstyle ':completion:*:git-checkout:*' sort false      # keep git branch order
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'  # case-insensitive match

# ── fzf-tab behaviour ─────────────────────────────────────────────────────────
zstyle ':fzf-tab:*' switch-group '<' '>'

# Fix: stop fzf-tab pre-filling the last completed word into the fzf query.
# 'prefix' = use only what's actually typed so far as the search seed.
zstyle ':fzf-tab:*' query-string prefix

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-flags '--height=50%' '--layout=reverse' '--info=inline'
zstyle ':fzf-tab:*' query-string prefix
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'

# ── Previews ──────────────────────────────────────────────────────────────────
# cd preview
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
  'eza --color=always --icons --group-directories-first $realpath 2>/dev/null || ls --color $realpath'

# mise task preview — external script to avoid inline quote escaping hell
zstyle ':fzf-tab:complete:mise:*' fzf-preview \
  'bash ~/.zsh/plugins/ "$word"'
