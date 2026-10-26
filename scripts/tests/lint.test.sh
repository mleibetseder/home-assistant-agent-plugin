#!/usr/bin/env bash
# Offline self-test for scripts/lint.sh: a clean fixture passes, each kind of defect is reported.
# shellcheck disable=SC2016 # backticks in the fixtures are literal Markdown
set -euo pipefail

script_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
lint="$script_dir/../lint.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
passed=0
fail() { echo "FAIL: $*" >&2; exit 1; }

skill() { # <name> <description> [body]
  mkdir -p "$work/skills/$1/agents"
  printf -- "---\nname: %s\nversion: 1.0.0\ndescription: '%s'\n---\n\n# %s\n%s\n" "$1" "$2" "$1" "${3:-}" >"$work/skills/$1/SKILL.md"
  printf 'interface:\n  display_name: "%s"\n' "$1" >"$work/skills/$1/agents/openai.yaml"
}
agent() { # <body>
  mkdir -p "$work/agents"
  printf -- "---\nname: helper\ndescription: 'Helps. Use for x.'\nmode: all\npermission:\n  edit: ask\n---\n%s\n" "$1" >"$work/agents/helper.md"
}
expect() { # <pattern>
  local out
  if out="$(bash "$lint" --root "$work" 2>&1)"; then fail "expected a finding matching: $1"; fi
  grep -qE -- "$1" <<<"$out" || fail "missing \"$1\" in: $out"
  passed=$((passed + 1))
}

skill alpha 'Does alpha. Use for alpha.' 'See `skills/beta`.'
skill beta 'Does beta. Use when beta.'
agent 'Uses the alpha skill.'
out="$(bash "$lint" --root "$work")" || fail "clean fixture failed: $out"
[[ "$out" == *"2 skills, 1 agents, all clean"* ]] || fail "unexpected output: $out"
passed=$((passed + 1))

skill gamma 'Gamma. Use for gamma.' 'Refers to `skills/missing`.'
expect 'gamma/SKILL.md:[0-9]+: unknown skill "skills/missing"'
skill gamma 'Gamma. Use for gamma.' 'Write to `config\packages`.'
expect 'gamma/SKILL.md:[0-9]+: backslash path'
skill gamma 'Gamma without a trigger.'
expect 'gamma/SKILL.md:1: description has no'
rm -rf "$work/skills/gamma"
printf -- "---\nname: helper\ndescription: 'Helps. Use for x.'\n---\nNo opencode keys.\n" >"$work/agents/helper.md"
expect 'agents/helper.md:1: no "mode"'

echo "lint self-test passed ($passed cases)."
