#!/usr/bin/env bash
# Offline self-test for scripts/eval-triggers.sh: distinct descriptions pass, a near miss that
# collides fails, and missing coverage fails.
set -euo pipefail

script_dir="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
eval_script="$script_dir/../eval-triggers.sh"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

passed=0
fail() { echo "FAIL: $*" >&2; exit 1; }
skill() { # <name> <description>
  mkdir -p "$work/skills/$1"
  printf -- "---\nname: %s\nversion: 1.0.0\ndescription: '%s'\n---\n" "$1" "$2" >"$work/skills/$1/SKILL.md"
}
cases() { mkdir -p "$work/evals"; printf '%b' "$1" >"$work/evals/triggers.tsv"; }

skill invoices 'Creates invoices from orders and sends them to customers. Use for "bill the customer".'
skill shipping 'Books parcel shipping labels with carriers. Use for "ship this order", "print a label".'
cases 'invoices\t+\tbill the customer for order 7\ninvoices\t+\tcreate invoices for last month\ninvoices\t+\tsend the invoice to the customer\ninvoices\t-\tprint a shipping label\nshipping\t+\tship this order\nshipping\t+\tbook a carrier label\nshipping\t+\tprint a label for the parcel\nshipping\t-\tbill the customer\n'
out="$(bash "$eval_script" --root "$work")" || fail "distinct skills failed: $out"
[[ "$out" == *"8/8 cases pass"* ]] || fail "unexpected output: $out"
passed=$((passed + 1))

# A near miss whose words all belong to the target fails.
cases 'invoices\t+\tbill the customer\ninvoices\t+\tcreate invoices\ninvoices\t+\tsend invoices\ninvoices\t-\tsend invoices to customers\nshipping\t+\tship this order\nshipping\t+\tbook a carrier label\nshipping\t+\tprint a label\nshipping\t-\tbill the customer\n'
if out="$(bash "$eval_script" --root "$work")"; then fail "colliding near miss passed: $out"; fi
[[ "$out" == *"FAIL - invoices"* ]] || fail "missing near-miss failure: $out"
passed=$((passed + 1))

# A skill without enough cases fails coverage.
cases 'invoices\t+\tbill the customer\ninvoices\t-\tprint a label\n'
if out="$(bash "$eval_script" --root "$work")"; then fail "missing coverage passed: $out"; fi
[[ "$out" == *"FAIL coverage: invoices has 1"* && "$out" == *"FAIL coverage: shipping has 0"* ]] || fail "missing coverage failure: $out"
passed=$((passed + 1))

echo "eval-triggers self-test passed ($passed cases)."
