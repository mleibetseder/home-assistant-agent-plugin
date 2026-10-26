#!/usr/bin/env bash
# Offline trigger eval: ranks every skill and agent of this plugin for each prompt in
# evals/triggers.tsv by the words it shares with the skill's name and description, weighted
# by how rare each word is (TF-IDF style). A "+" case passes when its skill ranks in the top 3,
# a "-" case (near miss) when its skill does not rank first. No model is called; the eval
# catches descriptions that are too vague or collide with a sibling.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/eval-triggers.sh [--root <repository>] [--verbose] [--help]

Reads evals/triggers.tsv (skill <TAB> +|- <TAB> prompt). Exit 0 all cases pass,
1 a case fails, 2 bad usage or a case names an unknown skill.
USAGE
}

root="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
verbose=0
while (($#)); do
  case "$1" in
    --root) [[ $# -ge 2 ]] || { echo "--root needs a value" >&2; exit 2; }; root="$(cd "$2" && pwd)"; shift 2 ;;
    --verbose) verbose=1; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done
cd "$root"
[[ -f evals/triggers.tsv ]] || { echo "missing evals/triggers.tsv" >&2; exit 2; }

# Coverage: every skill of ours has at least three "+" cases and one "-" case.
missing=0
for file in skills/*/SKILL.md; do
  name="$(basename "$(dirname "$file")")"
  plus="$(awk -F'\t' -v n="$name" '$1 == n && $2 == "+"' evals/triggers.tsv | wc -l)"
  minus="$(awk -F'\t' -v n="$name" '$1 == n && $2 == "-"' evals/triggers.tsv | wc -l)"
  if ((plus < 3 || minus < 1)); then echo "FAIL coverage: $name has $plus \"+\" and $minus \"-\" cases (need 3 and 1)"; missing=1; fi
done

# One line per skill or agent (agents compete for the same prompts): name <TAB> name and description.
corpus() {
  { find skills -name SKILL.md 2>/dev/null; find agents -name '*.md' 2>/dev/null; } | sort | while IFS= read -r file; do
    awk 'NR > 1 && $0 == "---" { exit }
      index($0, "name: ") == 1 { name = substr($0, 7) }
      index($0, "description: ") == 1 { description = substr($0, 14) }
      END { gsub(/["'\'']/, "", name); print name "\t" name " " description }' "$file"
  done
}

LC_ALL=C awk -F'\t' -v verbose="$verbose" '
  function words(text, out,    n, i, list, w) {
    delete out
    text = tolower(text)
    gsub(/[^a-z0-9\200-\377]+/, " ", text)
    n = split(text, list, " ")
    for (i = 1; i <= n; i++) {
      w = list[i]
      if (length(w) < 3 || w in stop) continue
      w = substr(w, 1, 6)                     # light stemming: a 6-letter prefix without plural s
      if (length(w) > 4 && w ~ /s$/) w = substr(w, 1, length(w) - 1)
      out[w] = 1
    }
  }
  BEGIN {
    split("the and for use with this that from into when what which our your are was has have not but all any its how why can its one per before after does like over only each every then them they their there here also more most than very just been being about", s, " ")
    for (i in s) stop[s[i]] = 1
  }
  FNR == NR {                                  # corpus: name <TAB> text
    skills[++count] = $1
    words($2, bag)
    for (w in bag) { has[count, w] = 1; df[w]++ }
    next
  }
  /^#/ || NF < 3 { next }                      # cases: skill <TAB> +|- <TAB> prompt
  {
    target = $1; expect = $2; prompt = $3; found = 0
    for (i = 1; i <= count; i++) if (skills[i] == target) found = 1
    if (!found) { print "unknown skill in evals/triggers.tsv: " target > "/dev/stderr"; unknown = 1; next }
    words(prompt, q)
    delete score
    for (i = 1; i <= count; i++) for (w in q) if ((i, w) in has) score[i] += log(count / df[w])
    # Rank of the target: 1 + skills with a strictly higher score; best = the top skill.
    tscore = 0; best = ""; bestscore = -1
    for (i = 1; i <= count; i++) {
      if (skills[i] == target) tscore = score[i] + 0
      if (score[i] + 0 > bestscore) { bestscore = score[i] + 0; best = skills[i] }
    }
    rank = 1
    for (i = 1; i <= count; i++) if (skills[i] != target && score[i] + 0 > tscore) rank++
    if (tscore == 0) rank = count
    ok = (expect == "+") ? (rank <= 3) : (rank > 1 || bestscore == 0)
    cases++; if (ok) passed++; else failed++
    if (!ok || verbose) printf "%s %s %-26s rank %-3d top %-26s | %s\n", (ok ? "pass" : "FAIL"), expect, target, rank, best, prompt
  }
  END {
    if (unknown) exit 2
    printf "eval-triggers: %d/%d cases pass against %d skills and agents\n", passed, cases, count
    exit failed ? 1 : 0
  }
' <(corpus) evals/triggers.tsv || exit $?
((missing == 0)) || exit 1
