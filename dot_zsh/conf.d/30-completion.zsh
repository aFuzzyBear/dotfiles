zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*' menu no
zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:*' fzf-flags '--height=50%' '--layout=reverse' '--info=inline'
zstyle ':fzf-tab:*' query-string prefix
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
