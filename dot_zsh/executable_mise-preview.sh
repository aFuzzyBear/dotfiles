#!/usr/bin/env bash
set -euo pipefail
json=$(timeout 3 mise tasks info "$1" --json 2>/dev/null) || {
  echo "preview unavailable for: $1"; exit 0
}
[ -z "$json" ] && { echo "no task info: $1"; exit 0; }

printf '%s' "$json" | jq -r '
  "Task:        " + (.name // "?"),
  "Description: " + (.description // ""),
  "Aliases:     " + (if ((.aliases // []) | length) > 0 then (.aliases | join(", ")) else "none" end),
  "Depends:     " + (if ((.depends // []) | length) > 0 then (.depends | join(", ")) else "none" end),
  "Source:      " + (.source // "?"),
  "",
  (if ((.usage_spec.cmd.args // []) | length) > 0 then
    "Args:",
    (.usage_spec.cmd.args[] |
      "  " + .name +
      (if .choices.choices then " (" + (.choices.choices | join("|")) + ")" else "" end) +
      "  " + (.help_first_line // ""))
  else empty end),
  (if ((.usage_spec.cmd.flags // []) | length) > 0 then
    "",
    "Flags:",
    (.usage_spec.cmd.flags[] | "  " + .usage + "  " + (.help_first_line // ""))
  else empty end),
  "",
  "Run:",
  ((.run // [])[] | "  " + .)
' | fold -s --width="${FZF_PREVIEW_COLUMNS:-80}"