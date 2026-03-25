
# ── History ───────────────────────────────────────────────────────────────────
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000

setopt HIST_EXPIRE_DUPS_FIRST   # drop dupes first when trimming
setopt HIST_IGNORE_DUPS         # don't record duplicate of previous
setopt HIST_IGNORE_SPACE        # don't record lines starting with space
setopt HIST_VERIFY              # confirm before executing from history
setopt HIST_SAVE_BY_COPY         # don't clobber history file when writing
setopt SHARE_HISTORY            # share history across sessions
setopt APPEND_HISTORY           # append rather than overwrite

