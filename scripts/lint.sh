#!/usr/bin/env bash
# Lints the skills and agents of this plugin: frontmatter, sizes, skill references, path
# separators, and that the Claude Code and opencode agent files share one body.
# Prints one "file:line: message" per finding; exit 1 on any finding.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/lint.sh [--root <repository>] [--help]

Checks skills/*/SKILL.md, agents/*.md and opencode/agents/*.md.
Exit 0 clean, 1 findings, 2 bad usage.
USAGE
}

root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
while (($#)); do
  case "$1" in
    --root) [[ $# -ge 2 ]] || { echo "--root needs a value" >&2; exit 2; }; root="$(cd "$2" && pwd)"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
cd "$root"

findings=0
report() { echo "$1: $2"; findings=$((findings + 1)); }

# Value of a one-line frontmatter key, without surrounding quotes.
field() {
  awk -v key="$2" 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit }
    NR > 1 && index($0, key ": ") == 1 { v = substr($0, length(key) + 3); gsub(/^'\''|'\''$|^"|"$/, "", v); gsub(/'\'''\''/, "'\''", v); print v; exit }' "$1"
}
has_key() { awk -v key="$2" 'NR > 1 && $0 == "---" { exit } NR > 1 && index($0, key ":") == 1 { found = 1 } END { exit !found }' "$1"; }
body() { awk 'NR == 1 && $0 == "---" { front = 1; next } front && $0 == "---" { front = 0; next } !front' "$1"; }

shopt -s nullglob
skills=(skills/*/SKILL.md)
agents=(agents/*.md)
declare -A known=()
for file in "${skills[@]}"; do known[$(basename "$(dirname "$file")")]=1; done

for file in "${skills[@]}"; do
  folder="$(basename "$(dirname "$file")")"
  description="$(field "$file" description)"
  [[ "$(field "$file" name)" == "$folder" ]] || report "$file:2" "name differs from folder \"$folder\""
  has_key "$file" version || report "$file:1" "frontmatter has no version"
  if [[ -z "$description" ]]; then report "$file:1" "no description"
  else
    ((${#description} <= 300)) || report "$file:1" "description has ${#description} characters (max 300)"
    [[ "$description" =~ Use\ (for|when) ]] || report "$file:1" "description has no \"Use for\" or \"Use when\""
  fi
  lines="$(wc -l <"$file")"
  ((lines <= 500)) || report "$file:1" "$lines lines (max 500)"
  [[ -f "$(dirname "$file")/agents/openai.yaml" ]] || report "$file:1" "no agents/openai.yaml (Codex metadata)"
done

for file in "${agents[@]}"; do
  id="$(basename "$file" .md)"
  [[ "$(field "$file" name)" == "$id" ]] || report "$file:2" "name differs from file name \"$id\""
  [[ -n "$(field "$file" description)" ]] || report "$file:1" "no description"
  twin="opencode/agents/$id.md"
  if [[ ! -f "$twin" ]]; then report "$file:1" "no opencode twin $twin"
  else
    [[ "$(field "$twin" description)" == "$(field "$file" description)" ]] || report "$twin:2" "description differs from $file"
    diff -q <(body "$file") <(body "$twin") >/dev/null || report "$twin:1" "body differs from $file; edit both or regenerate"
  fi
done

while IFS= read -r file; do
  # References to other skills of this plugin.
  while IFS=: read -r line ref; do
    [[ -n "${known[${ref#*skills/}]:-}" ]] || report "$file:$line" "unknown skill \"skills/${ref#*skills/}\""
  done < <(grep -noE '(^|[^a-z/.-])skills/[a-z0-9][a-z0-9-]*' "$file" || true)
  while IFS=: read -r line _; do report "$file:$line" "backslash path; use /"; done < <(grep -nE '[A-Za-z>]\\[A-Za-z]' "$file" || true)
done < <(find skills agents opencode -name '*.md' | sort)

if ((findings)); then echo "lint: $findings finding(s)"; exit 1; fi
echo "lint: ${#skills[@]} skills, ${#agents[@]} agents, all clean"
