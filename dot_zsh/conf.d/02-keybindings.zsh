# ── Keymap ────────────────────────────────────────────────────────────────────
# Emacs keymap — this is the root fix. Without this, Ctrl+A/E and many
# other bindings simply don't exist in zsh's default `main` keymap.
bindkey -e

# ── Line navigation ───────────────────────────────────────────────────────────
bindkey "^A" beginning-of-line
bindkey "^E" end-of-line

# ── Word navigation ───────────────────────────────────────────────────────────
# Ctrl+Right / Ctrl+Left — terminal sends these escape sequences
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

# Fallback sequences (some terminals differ)
bindkey "^[^[[C"  forward-word
bindkey "^[^[[D"  backward-word

# ── Word deletion ─────────────────────────────────────────────────────────────
bindkey "^[^?" backward-kill-word   # Alt+Backspace
bindkey "^[d"  kill-word            # Alt+D (kill forward word)
bindkey "^H"   backward-delete-char # Ctrl+Backspace (some terminals)

# ── History navigation ────────────────────────────────────────────────────────
# Ctrl+Up / Ctrl+Down — prefix-aware history search
bindkey "^[[1;5A" history-search-backward
bindkey "^[[1;5B" history-search-forward

# Ctrl+P / Ctrl+N — classic fallbacks (always reliable)
bindkey "^P" up-line-or-search
bindkey "^N" down-line-or-search

# ── Misc ──────────────────────────────────────────────────────────────────────
bindkey "^U" kill-whole-line        # Ctrl+U — clear line
bindkey "^K" kill-line              # Ctrl+K — kill to end of line
bindkey "^W" backward-kill-word    # Ctrl+W — delete word backward
