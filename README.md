# Home Assistant agent plugin

An AI coding agent and seven skills for building and maintaining a [Home Assistant](https://www.home-assistant.io) setup: automations, scripts, blueprints, templates, configuration, dashboards, devices (Zigbee, Matter, ESPHome) and custom integrations. Works with Claude Code, opencode, Codex and other tools that read [Agent Skills](https://agentskills.io).

It is built to be safe in a real home: it reads your instance first, uses your real entity IDs and the syntax of your Home Assistant version, and changes nothing without your approval.

> Not affiliated with or endorsed by Home Assistant or the Open Home Foundation.

## Safety model

| Rule | Why |
|---|---|
| Read first, act after approval | Every change (action call, configuration write, reload, restart, update, restore, deletion) is shown as an exact preview and needs your OK. |
| Security devices one at a time | Locks, alarm panels, covers (garage doors, gates), valves and sirens: every single action needs its own approval; never batched, scheduled or "tested". Home Assistant itself does not ask for confirmation here. |
| Facts from your instance | Version from `/api/config`, entity IDs and actions from `/api/states` and `/api/services`; an unknown ID is a question, not a guess. |
| Safe changes | Backup → edit → configuration check → smallest reload; never `.storage/` edits; never `POST /api/states` to "switch" a device. |
| Secrets | Token only from `HASS_SERVER` / `HASS_TOKEN`; never printed, never committed; `secrets.yaml` stays private. |

## What is inside

| | Name | Use it for |
|---|---|---|
| Agent | [`home-assistant-engineer`](agents/home-assistant-engineer.md) | Anything Home Assistant; loads the skills below as needed |
| Skill | [`ha-live-instance`](skills/ha-live-instance/SKILL.md) | Talking to a live instance (REST, WebSocket, MCP, `ha` CLI) |
| Skill | [`ha-automations`](skills/ha-automations/SKILL.md) | Automations, scripts, blueprints, syntax by version, traces |
| Skill | [`ha-templates`](skills/ha-templates/SKILL.md) | Jinja templates, modern `template:` entities |
| Skill | [`ha-configuration`](skills/ha-configuration/SKILL.md) | Packages, secrets, checks, backups, recorder, updates |
| Skill | [`ha-dashboards`](skills/ha-dashboards/SKILL.md) | Sections-view dashboards for phones and wall tablets |
| Skill | [`ha-devices`](skills/ha-devices/SKILL.md) | Local-first devices, Zigbee, Matter and Thread, ESPHome |
| Skill | [`ha-integration-dev`](skills/ha-integration-dev/SKILL.md) | Custom integrations in Python, quality scale, HACS |

Facts were checked against the Home Assistant, contributors and ESPHome documentation for Home Assistant 2026.10. The skills name the version a feature arrived in, so older installs get matching syntax.

## Install

**Claude Code** (plugin marketplace):

```bash
claude plugin marketplace add mleibetseder/home-assistant-agent-plugin
claude plugin install home-assistant@home-assistant-agent-plugin
```

Claude Code agents cannot carry their own shell permissions, so add ask rules to your `~/.claude/settings.json` (or the project's `.claude/settings.json`):

```json
{
  "permissions": {
    "ask": [
      "Bash(ha core restart:*)", "Bash(ha core update:*)", "Bash(ha os update:*)",
      "Bash(ha host reboot:*)", "Bash(ha backups restore:*)", "Bash(ha backups remove:*)",
      "Bash(curl -X POST:*)", "Bash(git push:*)"
    ]
  }
}
```

**opencode:** copy (or symlink) `opencode/agents/home-assistant-engineer.md` to `~/.config/opencode/agents/` and each folder of `skills/` to `~/.config/opencode/skills/`. The opencode agent file carries the ask rules in its `permission` block.

**Codex and other Agent Skills tools:** the repository has a Codex plugin manifest (`.codex-plugin/plugin.json`, `.agents/plugins/marketplace.json`); or copy the folders of `skills/` into `~/.agents/skills/` (Codex) or your tool's skills folder.

## Connect to your Home Assistant

1. In Home Assistant create a dedicated user for the agent (admin only if it should change configuration; local access only), then a long-lived access token under Profile → Security.
2. Export it where the agent runs, never in a file in a repository:

   ```bash
   export HASS_SERVER=http://homeassistant.local:8123
   export HASS_TOKEN=<token>
   ```

3. Optional: Home Assistant's built-in **MCP Server** integration (Settings → System → AI on 2026.10+) gives MCP clients the Assist API. It only sees entities exposed to voice; keep locks, alarm panels and garage doors unexposed unless you want them voice-controlled.

Then ask, for example: *"Write an automation that turns the hallway light on with motion after sunset"*, *"Why does my heating automation not fire?"*, *"Build a dashboard for the kitchen tablet"*.

## Quality checks

```bash
bash scripts/check.sh            # lint, offline trigger eval, self-tests, shellcheck, manifests (CI runs this)
bash scripts/eval-guardrails.sh  # behaviour eval under pressure, calls the model; add --baseline to compare
```

- **Lint** (`scripts/lint.sh`): frontmatter, sizes, skill references, Codex metadata, and that the Claude Code and opencode agent files share one body.
- **Trigger eval** (`evals/triggers.tsv`): three prompts and one near miss per skill, ranked offline against every skill and the agent.
- **Guardrail eval** (`evals/guardrails.tsv`): pressure cases run headless with no tools, compared with a generic assistant prompt; results in [`evals/RESULTS.md`](evals/RESULTS.md).

## Fork and adapt

See [AGENTS.md](AGENTS.md) for the layout and the rules to keep when you change or add skills. Pull requests welcome; security issues: [SECURITY.md](SECURITY.md).

## Related work

- [homeassistant-ai/skills](https://github.com/homeassistant-ai/skills) and [ha-mcp](https://github.com/homeassistant-ai/ha-mcp): community best-practice skill and MCP server with configuration tools (MIT).
- Home Assistant core ships contributor skills for core development in its own repository.

## Licence

[MIT](LICENSE)
