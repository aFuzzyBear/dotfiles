# ── Completion paths ──────────────────────────────────────────────────────────
# Dedupe FIRST — VSCode shell-integration re-sources conf.d, prepending
# ~/.zsh/completions multiple times. A duplicated fpath makes compinit's scan
# unreliable (some functions silently fail to register).
typeset -U fpath path

# User completions first (so they override system ones)
fpath=(~/.zsh/completions $fpath)

# ── Init ──────────────────────────────────────────────────────────────────────
autoload -Uz compinit

# Rebuild dump (full fpath scan) at most once per 24h; otherwise trust it.
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# ── Core behaviour ────────────────────────────────────────────────────────────
zstyle ':completion:*' menu select
zstyle ':completion:*' verbose yes
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# NOTE: deliberately NOT setting `group-name ''` — that flattens groups and
# suppresses the description column that fzf-tab renders.

# ── fzf-tab behaviour ─────────────────────────────────────────────────────────
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' show-group full

zstyle ':fzf-tab:*' fzf-flags \
  '--height=50%' \
  '--layout=reverse' \
  '--info=inline'

# Stop fzf-tab pre-filling the last completed word into the fzf query
zstyle ':fzf-tab:*' query-string prefix

# ── Previews ──────────────────────────────────────────────────────────────────
# cd preview
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
  'eza --color=always --icons --group-directories-first $realpath 2>/dev/null || ls --color $realpath'

# mise task preview — anchored to the TASK-NAME position only.
# fzf-tab's completion context for a positional task name is `mise:argument-rest`
# (or `:argument-1`). Anchoring there stops the preview firing on file/flag
# arguments, which is what produced the "preview unavailable for: .chezmo" leak.
zstyle ':fzf-tab:complete:mise:argument-1' fzf-preview \
  'bash ~/.zsh/mise-preview.sh "$word"'

# Belt-and-braces: empty preview on every OTHER mise context, so file/flag
# completions never invoke the task previewer.
zstyle ':fzf-tab:complete:mise:*' fzf-preview ''