# ── Navigation ────────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# ── Listing — eza over ls ─────────────────────────────────────────────────────
if command -v eza &>/dev/null; then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lahF --icons --group-directories-first --git'
  alias la='eza -a --icons --group-directories-first'
  alias lt='eza --tree --icons --level=2'              # tree view, 2 levels
  alias ltt='eza --tree --icons --level=3'             # tree view, 3 levels
else
  alias ls='ls --color=auto'
  alias ll='ls -lahF --color=auto'
  alias la='ls -A --color=auto'
fi

# ── bat — cat with syntax highlighting ───────────────────────────────────────
if command -v bat &>/dev/null; then
  alias cat='bat --paging=never'   # cat-like (no pager by default)
  alias bат='bat'                  # with pager when you want it
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"  # pretty man pages
  export BAT_THEME="Catppuccin-mocha"                 # change to taste
fi

# ── ripgrep ───────────────────────────────────────────────────────────────────
if command -v rg &>/dev/null; then
  alias grep='rg'
fi

# ── fd ────────────────────────────────────────────────────────────────────────
if command -v fd &>/dev/null; then
  alias find='fd'
fi

# ── btop ─────────────────────────────────────────────────────────────────────
alias top='btop'

# ── xh — http client ──────────────────────────────────────────────────────────
# alias curl='xh'  # opt-in — uncomment if you want this, xh flags differ enough
#                  # that a blind alias will bite you eventually

# ── tldr ─────────────────────────────────────────────────────────────────────
alias help='tealdeer'
alias tldr='tealdeer'   # muscle memory alias
# ── Git ───────────────────────────────────────────────────────────────────────
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias glog='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gd='git diff'

# ── pnpm ──────────────────────────────────────────────────────────────────────
alias pn='pnpm'
alias pni='pnpm install'
alias pna='pnpm add'
alias pnr='pnpm run'
alias pnx='pnpm exec'

# ── Mise ──────────────────────────────────────────────────────────────────────
alias mt='mise tasks'
alias mr='mise run'

# ── chezmoi — dotfiles sync ───────────────────────────────────────────────────
alias cz='chezmoi'
alias czs='chezmoi status --color=auto' # what's changed locally vs source, with colour
alias czcd='chezmoi cd'              # cd into chezmoi source directory
alias czst='chezmoi status'          # what's changed locally vs source
alias czap='chezmoi apply'           # apply source → home (pull from remote first)
alias czdiff='chezmoi diff'            # preview what apply would change
alias czpush='chezmoi add -r ~/.zsh && chezmoi cd && git push && cd -'

# ── Docker ────────────────────────────────────────────────────────────────────
alias dk='docker'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'