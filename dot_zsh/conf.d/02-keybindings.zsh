# ── Keymap mode ───────────────────────────────────────────────────────────────
# Use Emacs-style editing (Ctrl+A/E, Alt+F/B, etc.)
bindkey -e

# Helper to inspect what escape sequences your terminal actually sends.
# Run: showkey
showkey() { cat -v; }

# ── Cleanup: remove weird or duplicate bindings ───────────────────────────────
# These appear when terminals send hybrid or partial escape sequences.
bindkey -r "^[^[[C"
bindkey -r "^[^[[D"
bindkey -r "^[B"
bindkey -r "^[F"

# ── Word navigation ───────────────────────────────────────────────────────────
# Alt + Left/Right (or Alt+b / Alt+f)
bindkey "^[b" backward-word
bindkey "^[f" forward-word

# Ctrl + Left/Right (modern terminals: iTerm2, macOS Terminal, VS Code, Kitty)
bindkey "^[[1;5D" backward-word   # Ctrl + Left
bindkey "^[[1;5C" forward-word    # Ctrl + Right

# ── Line navigation ───────────────────────────────────────────────────────────
# Home / End keys
bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line

# Some terminals send these instead:
bindkey "^[OH" beginning-of-line
bindkey "^[OF" end-of-line

# ── Deletion behaviour ────────────────────────────────────────────────────────
# Delete key (forward delete)
bindkey "^[[3~" delete-char

# Option + Delete (delete previous word)
bindkey "^[^?" backward-kill-word

# Ctrl + Delete (delete next word)
bindkey "^[[3;5~" kill-word

# ── History navigation ────────────────────────────────────────────────────────
# Search backward/forward through history with Ctrl+R / Ctrl+S
bindkey "^R" history-incremental-search-backward
bindkey "^S" history-incremental-search-forward

# ── Misc ergonomics ───────────────────────────────────────────────────────────
# Ctrl+K: kill to end of line (default)
# Ctrl+U: kill to beginning of line (default)
# Ctrl+Y: yank (default)
# Ctrl+W: delete previous word (default)

# Make Ctrl+L clear screen consistently
bindkey "^L" clear-screen

# Make Ctrl+P / Ctrl+N behave like up/down arrows (Emacs muscle memory)
bindkey "^P" up-line-or-history
bindkey "^N" down-line-or-history
