# ── Shell functions ───────────────────────────────────────────────────────────

# Edit a chezmoi-managed file in source and apply immediately on exit
czedit() {
  chezmoi edit "$1" && chezmoi apply
}
