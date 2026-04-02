# `gh` Task Suite — Design Decisions

> Captured during initial build session, April 2026.
> Intended as source material for the suite README.

---

## Tool structure

**`mise-tasks/gh/` subdirectory** creates the `gh:*` task namespace automatically via mise's directory grouping. All tools live under this prefix. Aliases follow the `gh<initial>` pattern (`ghi`, `ghp`, `ghbp`, `ghbl`, `ghs`, `ghsp`, `ghrl`).

**`#MISE dir="{{cwd}}"`** on every task — tools run from the invocation directory, not the `mise.toml` root. Without this, `gh` context resolution breaks when invoked from a subdirectory.

---

## Argument parsing

**Manual `case`-based flag parsing over `usage_json` injection.** The `#USAGE` annotations are kept for completions and `--help` documentation, but runtime flag handling is done explicitly via `for arg in "$@"; do case ...`. Reason: `usage_json` environment injection only works when the `usage` CLI is installed. Without it, unrecognised flags fall through to `parse_selector` and produce confusing errors. The `#USAGE` annotation is documentation; the `case` block is the contract.

**`while [[ $# -gt 0 ]]; do case ... shift`** used instead of `for arg` when a flag consumes the next positional (e.g. `--branch <name>`). The `for` loop cannot consume lookahead; `while` with explicit `shift 2` can.

---

## Array handling under `set -u`

**`mapfile -t` over word-split subshells.** `arr=($(command))` does word-splitting and is unsafe on output containing spaces. `mapfile -t arr < <(command)` is the correct idiom.

**Empty array guard.** `${arr[@]:-}` expands to `""` (empty string) when the array is empty under `set -u`, not to nothing. This causes `printf '%s\n' "${arr[@]:-}"` to emit a blank line, which `jq -R 'tonumber'` then rejects. Fix: explicit length check before any array-to-JSON conversion:
```bash
if [[ ${#arr[@]} -gt 0 ]]; then
  json=$(printf '%s\n' "${arr[@]}" | jq -R 'tonumber' | jq -s '.')
else
  json='[]'
fi
```

**`queue+=("$neighbor"); mapfile -t queue < <(... | sort -n)`** for sorted queue insertion. `printf "%s\n" "${queue[@]:-}" "$neighbor"` produces a blank line when queue is empty, corrupting the next iteration's node lookup. Append-then-sort is safe because `"${queue[@]}"` is only evaluated after a non-empty append.

---

## JSON output patterns

**Loop stdout piped into `jq -s '.'`** to collect multiple `gh` call outputs into a single JSON array:
```bash
for num in "${nums[@]}"; do
  gh issue view "$num" --json "$FIELDS"
done | jq -s '.'
```
No temp files, no trap, no cleanup. Each `gh` call emits a single JSON object; `jq -s '.'` slurps the stream into an array.

**Single-item tools emit a bare object; multi-item tools emit an array.** `gh-branch-pr` returns one PR as `{}`. `gh-issues`, `gh-prs`, `gh-sprint` return `[]`. This matches the natural cardinality of each tool and makes `jq` usage at the callsite predictable.

**`--json` flag handled manually in all tools.** Same reasoning as arg parsing above — no `usage` dependency.

---

## Logical reference resolution (`$lmap`)

**The `[X.Y]` title prefix convention is machine-resolvable.** Issue bodies use logical refs (`#1.3`, `#2.1`) rather than raw GitHub issue numbers. These map to GitHub issue numbers via the `[X.Y]` prefix in each issue's title.

**`$lmap` is built at graph-build time** by extracting the `[X.Y]` prefix from every issue title in the queried set:
```jq
(map({
  key:   (.title | ltrimstr("[") | split("]")[0]),
  value: .number
})
| map(select(.key | test("^[0-9]+(\\.[0-9]+)+")))
| map({(.key): .value})
| add // {}) as $lmap
```

**`test("\\.")` is the branching signal.** A ref containing a dot is a logical ref (resolved via `$lmap`). A ref without a dot is a real GitHub issue number (direct `tonumber`). The `// empty` on lmap lookup silently drops refs to issues outside the queried set — correct behaviour, not data loss.

**`[X]` single-segment format is deliberately unsupported.** A body ref of `#1` is ambiguous: it could be logical epic `[1]` or GitHub issue #1. The dot is the only unambiguous signal. Epics should use `[1.0]` if they need to participate in the logical numbering system.

**Supported formats:** `[X.Y]` and `[X.Y.Z]` (and deeper). Regex: `test("^[0-9]+(\\.[0-9]+)+")` — one or more dot segments required.

---

## Dependency graph and topological sort

**In-set filtering.** When building the graph for a specific set of issues (e.g. a sprint milestone), `blockedBy` and `blocks` references are filtered to only include issues *within that set*. External references are excluded from in-degree calculations. Rationale: an external blocker inflates in-degree and causes an issue to never leave the queue, breaking the sort for the entire sprint. External refs are still displayed in pretty output for human context.

**Kahn's algorithm in bash.** Standard BFS-based topological sort. Queue seeded with zero-in-degree nodes, sorted numerically for deterministic output. On each step, decrement in-degree of dependents; add newly unblocked nodes to queue.

**Orphan detection.** An issue with no in-set `blockedBy` AND no in-set `blocks` is parallelisable — no coordination required. Emitted as a separate section rather than buried in the execution order. Useful for splitting work across collaborators.

**Cycle detection.** Any issue not emitted by Kahn's (in-degree never reaches zero) indicates a cycle. These are flagged loudly in both pretty and JSON output rather than silently dropped or causing a hang.

---

## Tool composition

**No inter-tool delegation at runtime.** Early version of `gh-blockers` attempted to call `gh-issues` as a subprocess. This created path-resolution complexity and silently swallowed errors. All tools inline their own fetching logic. Shared logic (selector parsing, `build_graph`) is duplicated deliberately — the tools are independently executable scripts, not a library.

**`|| echo "[]"` for optional `gh` calls.** `gh run list` on a branch with no CI history exits non-zero. Guarded with `|| echo "[]"` to prevent cascading failure in `gh-status`.

**`gh pr list --search "review-requested:@me"`** preferred over `--review-requested @me` for composability — the search form can be extended with additional qualifiers without restructuring the call.

---

## Label taxonomy — `gh-labels.toml`

**GitHub UI is a projection, not the source of truth.** Labels are defined in `.github/gh-labels.toml` and applied to GitHub via `mr gh:labels:sync`. The UI reflects the file; it does not define it. This inverts the usual workflow where the GUI is authoritative and scripts are derived from it.

**Why not `gh label list` as source of truth?** `gh label list` gives you label names but no classification — it cannot tell you that `p0`/`p1`/`p2` are a priority group and `auth`/`bff`/`ssr` are a domain group. That structure is implicit in naming conventions. Encoding it explicitly in a config file makes it machine-readable and version-controlled alongside the code.

**Group semantics.** Labels are organised into named groups with two boolean flags: `required` (at least one must be present) and `exclusive` (at most one may be present). The combination of these two flags gives four distinct enforcement modes — exactly one, at least one, at most one, or unconstrained. The `meta` group uses the unconstrained mode (`required = false`, `exclusive = false`).

**`[[rules]]` for cross-cutting constraints.** Group membership checks cover structural hygiene (missing labels, duplicate labels). The `[[rules]]` block covers conditional constraints that depend on which specific label is present or what state the issue is in — for example, `p0` issues requiring an assignee. Rules have a `when` condition and a `require` assertion. Currently supported `require` values: `assignee`, `milestone`.

**awk-based TOML parsing, deliberately.** No external parser dependency — `gh:drift` uses targeted `awk` to extract the known fields from the known schema. This is a pragmatic tradeoff: the schema is stable and regular enough that awk works correctly, and zero dependencies is a meaningful property for a task that runs on every developer machine. The limitation is that the parser is not a general TOML parser — it enforces specific formatting constraints documented in the spec. If the schema grows significantly in complexity, replacing the awk implementation with `dasel` or `tomljson` is the correct response.

**Blank line as rule separator.** `[[rules]]` blocks must be separated by a blank line — this is the awk end-of-rule signal, not a TOML requirement. It's a parser constraint documented explicitly in the spec to prevent silent misparse.

**`gh:labels:sync` is implied but deferred.** The write-side complement to `gh:drift`. Will use `gh label create` / `gh label edit` to reconcile GitHub's label state against the TOML. Until it exists, label creation is manual in the UI — the TOML remains authoritative regardless.

## `gh-drift`

**Informational by default, strict mode opt-in.** `gh:drift` exits 0 regardless of violations unless `--strict` is passed. This makes it safe to run in a pre-push hook without blocking work — violations are surfaced as information, not hard stops. `--strict` enables exit 1 on any violation for CI gate use.

**`--stale` is opt-in.** Checking whether blockers reference closed issues requires one `gh issue view` call per blocker reference across all open issues. On a large issue list this is meaningful API traffic. The flag makes the cost explicit and deliberate.

**Violations are structured JSON internally.** Even in pretty mode, violations are collected as JSON objects and rendered at the end. This means `--json` mode is a free output of the same data structure, not a separate code path.

## Issue title format — `(scope)[X.Y.Z]`

**The title is a machine-readable contract, not just a label.** The `(scope)[X.Y.Z] Description` format encodes two independent axes of classification in a single field: which part of the codebase (`scope`) and where in the work breakdown structure (`X.Y.Z`). Both are optional — issues without either are valid and handled gracefully by all tools.

**`$lmap` key collision was the forcing function.** The original `[X.Y.Z]` format used `X.Y.Z` as the `$lmap` key. In a monorepo with multiple workstreams, two independent workstreams can legitimately both have an issue at position `1.3` — and they'd collide silently. The scope prefix makes keys globally unique by construction: `auth/1.3` and `bff/1.3` are structurally distinct.

**Cross-reference syntax in bodies: `(scope)#X.Y.Z`.** Body refs use the same scope prefix: `Blocked by: (auth)#1.3, (bff)#2.1`. This is the canonical form. Unscoped `#X.Y.Z` (legacy) and plain `#N` (raw GitHub issue number) are also supported for backward compatibility. Ref resolution applies in that order: scoped → unscoped dotted → plain integer.

**Three-level depth cap is a discipline decision, not a tooling limit.** The tools support arbitrary depth. The convention caps at three: `X.0` (epic), `X.Y` (story), `X.Y.Z` (task). A fourth level is a signal that scope management belongs in the issue body, not the title. `gh:issue:create` warns on depth > 3 but does not refuse.

**`.0` suffix marks epics.** `[1.0]` is the parent epic for the `1.x` workstream. `[1]` without a dot is explicitly invalid as a logical ref — it is ambiguous with raw GitHub issue numbers in body cross-references. The `.0` suffix preserves the dot signal that the ref resolution logic uses to distinguish logical refs from GitHub issue numbers.

**Backward compatibility is first-class.** The legacy `[X.Y.Z]` format (no scope) continues to work. `$lmap` keys for legacy issues are `X.Y.Z` (not `scope/X.Y.Z`). Legacy unscoped body refs `#X.Y.Z` resolve against legacy keys. Tools do not require migration of existing issues.

**`def resolve_refs` in jq eliminates double-matching.** The previous implementation used two sequential `scan` calls which could match `(auth)#1.3` as both a scoped ref and `#1` (the integer prefix). The new implementation uses `gsub` to strip scoped refs before scanning for plain refs, ensuring each ref is resolved exactly once regardless of format.



- `gh-blockers` and `gh-sprint` share `build_graph` logic but it currently lives in each file separately. Extract to a shared snippet when the suite stabilises.
- `gh-blockers` pretty output shows truncated logical refs (e.g. `#1` from `#1.3`) when used outside a sprint context. Low priority since `gh-sprint --pretty` is the canonical dependency view.
- `gh-run-log` cannot surface logs for certain runner types via `--log-failed` — `gh` CLI limitation, not a script bug.
- `gh-sprint` fetches issues sequentially. For large milestones, parallelise with `&` + `wait` and temp files.