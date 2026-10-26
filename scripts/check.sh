#!/usr/bin/env bash
# The gate of this repository: lint, offline trigger eval, self-tests, shellcheck and manifest
# consistency. Exit 1 on any failure. The guardrail eval (scripts/eval-guardrails.sh) calls a
# model and is run separately.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/check.sh [--help]

Runs the lint, the trigger eval, the self-tests, shellcheck and a manifest check.
Needs bash 4.4+, jq, coreutils and shellcheck.
USAGE
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }

root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
cd "$root"
for tool in jq shellcheck; do
  command -v "$tool" >/dev/null || { echo "missing: $tool (install it with your package manager)" >&2; exit 2; }
done

failed=0
step() { echo "== $*"; }
run() { "$@" || { echo "FAILED: $*" >&2; failed=1; }; }

step "lint"
run bash scripts/lint.sh
step "trigger eval"
run bash scripts/eval-triggers.sh
step "self-tests"
for test in scripts/tests/*.test.sh; do run bash "$test"; done
step "shellcheck"
run shellcheck -x scripts/*.sh scripts/tests/*.sh

step "manifests"
# Name, version and description agree across the plugin manifests.
for key in name version description; do
  values="$(for f in plugin.json .claude-plugin/plugin.json .codex-plugin/plugin.json; do jq -r ".$key" "$f"; done | sort -u | wc -l)"
  [[ "$values" == 1 ]] || { echo "FAILED: \"$key\" differs between plugin.json, .claude-plugin/plugin.json and .codex-plugin/plugin.json" >&2; failed=1; }
done
jq -e '.plugins[] | select(.name == "home-assistant" and .source == "./")' .claude-plugin/marketplace.json >/dev/null \
  || { echo "FAILED: .claude-plugin/marketplace.json has no entry home-assistant -> ./" >&2; failed=1; }

if ((failed)); then echo "check: FAILED"; exit 1; fi
echo "check: all passed"
