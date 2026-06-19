# ── Plugins ───────────────────────────────────────────────────────────────────
# Guarded sourcing: a missing plugin dir warns instead of throwing.

_load_plugin() {
  local file="$1"
  if [[ -r "$file" ]]; then
    source "$file"
  else
    print -u2 "zsh: plugin missing, skipped: ${file:h:t}/${file:t}"
  fi
}
# fzf-tab MUST be sourced last, and after compinit (20-completion.zsh).
_load_plugin ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh

# History substring search — NOTE: this binds ↑/↓ (^[[A / ^[[B) to its own
# widgets, which CLOBBERS atuin's up-arrow bound back in 10-tools.zsh.
_load_plugin ~/.zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Alias coaching
_load_plugin ~/.zsh/plugins/zsh-you-should-use/you-should-use.plugin.zsh


# Syntax highlighting — must come BEFORE fzf-tab, AFTER compinit.
_load_plugin ~/.zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh


unfunction _load_plugin

# ── Self-registering completion scripts ───────────────────────────────────────
# Tools whose `completion zsh` output is NOT a #compdef-convention file but a
# self-registering script that calls compdef internally (mise, pnpm, varlock).
# These cannot live in ~/.zsh/completions/ (compinit autoload assumes the
# function name matches the filename — it doesn't for these, so the bind fails
# silently). Instead they go in completions.d/ and are SOURCED here, after
# compinit (20-completion.zsh) has made compdef available.
#
# Generic: drop any self-registering script into completions.d/ and it loads.
# No per-tool evals, no hardcoded names.
for f in ~/.zsh/completions.d/*(N); do source "$f"; done