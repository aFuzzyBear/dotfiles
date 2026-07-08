# ── Shell functions ───────────────────────────────────────────────────────────

# Edit a chezmoi-managed file in source and apply immediately on exit
czedit() {
  chezmoi edit "$1" && chezmoi apply
}

# Create a directory and cd into it
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }

# Go up N directories 
up() {
  local n="${1:-1}" path=""
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "up: not a number: $n" >&2; return 1; }
  while (( n-- > 0 )); do path+="../"; done
  cd "$path"
}