# AGENTS.md

Rules for people and coding agents changing this repository: one Home Assistant agent and its skills, packaged for Claude Code, opencode, Codex and other Agent Skills tools.

## Layout

| Path | What it is |
|---|---|
| `agents/home-assistant-engineer.md` | The agent: one file in opencode format (`name`, `description`, `mode`, `permission`). opencode uses all keys; Claude Code reads `name` and `description` and ignores the rest. |
| `skills/<name>/SKILL.md` | Skills in the [Agent Skills](https://agentskills.io) format; `skills/<name>/agents/openai.yaml` holds Codex display metadata. |
| `plugin.json`, `.claude-plugin/`, `.codex-plugin/`, `.agents/plugins/` | Plugin and marketplace manifests; name, version and description agree across them. |
| `evals/` | `triggers.tsv` (trigger eval), `guardrails.tsv` (behaviour eval), `RESULTS.md`. |
| `scripts/` | `check.sh` (the gate), `lint.sh`, `eval-triggers.sh`, `eval-guardrails.sh`, `tests/`. |

## Non-negotiable safety rules

Every change keeps these, in the agent and in every skill:

1. Read the live instance first; change it only after the user approved the exact change.
2. Locks, alarm panels, covers, valves and sirens: one approved action at a time; never batched, scheduled or used as a test.
3. Entity IDs, actions and the version come from the instance, never invented.
4. Backup → edit → configuration check → smallest reload; never edit `.storage/`; never `POST /api/states` to control a device.
5. Tokens from `HASS_SERVER` / `HASS_TOKEN` only; never printed or committed; `secrets.yaml` stays private.

## Writing skills

- Folder name = frontmatter `name`, lowercase with hyphens, prefix `ha-`. Frontmatter: `name`, `version` (semantic), `description` of at most 300 characters that says what it does and when to use it (`Use for "…"`).
- At most 500 lines; short procedures and rules, not tutorials. Refer to sibling skills as `skills/<name>`.
- **Facts are versioned and sourced.** Name the Home Assistant (or ESPHome) version a feature or rename arrived in; check it against home-assistant.io, contributors.home-assistant.io (the developer docs moved there) or esphome.io. When unsure, tell the agent to read the user's version and the current docs.
- English, plain language, forward slashes in paths, no personal data, no real tokens, hostnames or IPs in examples (`homeassistant.local` is fine).

## Changing the agent

There is one agent file, in opencode format with `name`; keep it that way (the lint requires `mode` and `permission`). Keep its `permission` ask rules and the Claude Code settings example in the README in sync.

## Evals

- Every skill has at least three trigger prompts and one near miss in `evals/triggers.tsv` (a near miss names this skill but belongs to another).
- Every new hard limit gets a pressure case in `evals/guardrails.tsv` that a generic assistant fails; check with `scripts/eval-guardrails.sh --case <id> --baseline`.

## Verify before you finish

```bash
bash scripts/check.sh                                # must pass; CI runs it on every push and pull request
bash scripts/eval-guardrails.sh --case <id>          # after changing a guardrail (calls the model)
```

Bump the version in all three plugin manifests and add a `CHANGELOG.md` entry for every user-visible change.
