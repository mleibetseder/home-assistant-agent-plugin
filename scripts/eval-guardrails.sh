#!/usr/bin/env bash
# Behaviour eval for guardrails: runs each case in evals/guardrails.tsv headless with Claude Code
# (`claude -p`), the agent's or skill's instructions as the system prompt and no tools, then
# grades the answer with the case's must / must-not patterns. Costs model calls, so it is not
# part of scripts/check.sh; run it weekly or after changing a guardrail.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/eval-guardrails.sh [--case <id>] [--model <model>] [--jobs <n>] [--baseline] [--write] [--help]

  --case <id>     run one case (default: all)
  --model <name>  model passed to claude (default: the claude default)
  --jobs <n>      cases in parallel (default 4)
  --baseline      same cases with a generic assistant prompt instead of our instructions,
                  to show which guardrails the instructions add
  --write         record the result table (and the baseline count) in evals/RESULTS.md
EVAL_KEEP=<folder> keeps every answer there for inspection.
Exit 0 all pass, 1 a case fails, 2 claude missing or bad usage.
USAGE
}

root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
only="" model="" jobs=4 write=0 baseline=0
while (($#)); do
  case "$1" in
    --case) only="${2:?--case needs a value}"; shift 2 ;;
    --model) model="${2:?--model needs a value}"; shift 2 ;;
    --jobs) jobs="${2:?--jobs needs a value}"; shift 2 ;;
    --write) write=1; shift ;;
    --baseline) baseline=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
command -v claude >/dev/null || { echo "claude (Claude Code CLI) is required: https://docs.claude.com/en/docs/claude-code" >&2; exit 2; }
cd "$root"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir "$work/empty"

# Instructions of agent:<id> or skill:<name> without frontmatter.
instructions() {
  local file
  if ((baseline)); then echo "You are a helpful assistant."; return; fi
  case "$1" in
    agent:*) file="agents/${1#agent:}.md" ;;
    skill:*) file="skills/${1#skill:}/SKILL.md" ;;
  esac
  [[ -n "${file:-}" ]] || { echo "unknown target $1" >&2; return 2; }
  awk 'NR == 1 && $0 == "---" { front = 1; next } front && $0 == "---" { front = 0; next } !front' "$file"
}

run_case() { # <id> <target> <must> <must_not> <prompt>
  local id="$1" target="$2" must="$3" must_not="$4" prompt="$5" answer result
  instructions "$target" >"$work/$id.system"
  # Isolated: empty working folder, no skills, settings, MCP servers or tools; only the system prompt.
  answer="$(cd "$work/empty" && claude -p --system-prompt-file "$work/$id.system" --tools "" --disable-slash-commands \
    --setting-sources "" --strict-mcp-config --no-session-persistence ${model:+--model "$model"} "$prompt" </dev/null 2>&1)" || true  # stdin would leak the case file
  printf '%s\n' "$answer" >"$work/$id.answer"
  [[ -z "${EVAL_KEEP:-}" ]] || cp "$work/$id.answer" "$EVAL_KEEP/$id.answer"
  result=pass
  grep -Eiq -- "$must" <<<"$answer" || result="FAIL (missing: $must)"
  if [[ "$must_not" != "-" ]] && grep -Eiq -- "$must_not" <<<"$answer"; then result="FAIL (found: $must_not)"; fi
  printf '%s\t%s\t%s\n' "$id" "$target" "$result" >"$work/$id.result"
}

count=0
while IFS=$'\t' read -r id target must must_not prompt; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  [[ -z "$only" || "$id" == "$only" ]] || continue
  run_case "$id" "$target" "$must" "$must_not" "$prompt" &
  count=$((count + 1))
  while (($(jobs -rp | wc -l) >= jobs)); do wait -n || true; done
done <evals/guardrails.tsv
wait
((count)) || { echo "no case matched" >&2; exit 2; }

table="$(cat "$work"/*.result | sort)"
passed="$(grep -c $'\tpass$' <<<"$table" || true)"
printf '%s\n' "$table" | column -t -s $'\t'
while IFS= read -r failed; do
  echo "--- answer of $failed (first 15 lines)"; head -15 "$work/$failed.answer"
done < <(awk -F'\t' '$3 != "pass" { print $1 }' <<<"$table")
echo "eval-guardrails: $passed/$count cases pass$( ((baseline)) && echo " (baseline: generic assistant prompt)")"

if ((write && baseline)); then
  [[ -f evals/RESULTS.md ]] || { echo "run with --write (without --baseline) first" >&2; exit 2; }
  sed -i '/^Baseline: /d' evals/RESULTS.md
  echo "Baseline: the same cases with a generic assistant prompt instead of our instructions pass $passed/$count, run $(date -u +%Y-%m-%d)." >>evals/RESULTS.md
elif ((write)); then
  {
    echo "# Eval results"
    echo
    echo "Guardrail behaviour eval (\`scripts/eval-guardrails.sh\`), run $(date -u +%Y-%m-%d) with Claude Code ${model:-default model}: **$passed/$count pass**."
    echo
    echo "| Case | Target | Result |"
    echo "|---|---|---|"
    awk -F'\t' '{ printf "| %s | `%s` | %s |\n", $1, $2, $3 }' <<<"$table"
    echo
    echo "Trigger eval (\`scripts/eval-triggers.sh\`, offline, part of \`scripts/check.sh\`): $(bash scripts/eval-triggers.sh | tail -1 | sed 's/^eval-triggers: //')."
  } >evals/RESULTS.md
fi
((passed == count))
