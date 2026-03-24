# Completion system
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit

# Emacs keybindings (fixes ctrl+a, ctrl+e, arrow navigation)
bindkey -e

# GPG TTY — required for pinentry in WSL
export GPG_TTY=$(tty)
