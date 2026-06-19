
# ── General ───────────────────────────────────────────────────────────────────
# setopt NO_BEEP            # disable the bell sound
setopt AUTO_CD            # cd by typing a directory name alone
setopt AUTO_PUSHD         # pushd on cd
setopt PUSHD_TO_HOME      # pushd with no args goes to $HOME
setopt PUSHD_SILENT       # don't print the directory stack after pushd

# ── Developer sanity ───────────────────────────────────────────────
setopt no_nomatch              # don't error on unmatched globs
setopt interactive_comments    # allow inline comments in commands
setopt glob_dots               # * matches dotfiles
setopt extended_glob           # advanced globbing patterns

# ── Pasting & multiline commands ───────────────────────────────────
setopt auto_continue           # paste multiline scripts cleanly
setopt ignore_eof              # avoid accidental shell exits

# ── Completion behaviour ───────────────────────────────────────────
setopt complete_in_word        # complete in the middle of a word
setopt always_to_end           # move cursor to end after completion
setopt auto_menu               # cycle through matches
