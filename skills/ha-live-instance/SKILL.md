---
name: ha-live-instance
version: 1.0.0
description: 'Reads and changes a live Home Assistant safely through REST, WebSocket, MCP or the ha CLI: version first, real entity IDs and actions, approval before any change. Use for "check my Home Assistant", "which entities do I have", "call this action".'
metadata:
  category: home-automation
---

# HA Live Instance

How an agent talks to a running Home Assistant. Reading is cheap and always comes first; every change follows the approval rules of `@Home Assistant Engineer`.

## Rules

1. **Credentials from the environment:** `HASS_SERVER` (for example `http://homeassistant.local:8123`) and `HASS_TOKEN` (a long-lived access token from Profile → Security), the same variables `hass-cli` uses. Never print the token, never put it in a file in a repository, never pass it on a command line that ends up in shell history or logs; use `-H "Authorization: Bearer $HASS_TOKEN"`. Recommend a dedicated user for the agent, local access only, and admin rights only when configuration work needs them.
2. **Version first:** `GET /api/config` returns `version`; choose syntax, UI menu names and features for that version (`skills/ha-automations` lists the changes by version).
3. **Real IDs only:** entity IDs, attributes and supported features from `GET /api/states` (or `get_states` over WebSocket); actions and their fields from `GET /api/services`. A target that does not exist does not fail an action, it is skipped with a warning, so a typo goes unnoticed: verify every ID you write.
4. **Changes only after approval** of the exact call; security devices (lock, alarm_control_panel, cover, valve, siren) one action at a time.

## Read

| Need | REST | WebSocket / other |
|---|---|---|
| Version, components, time zone | `GET /api/config` | `get_config` |
| States and attributes | `GET /api/states`, `GET /api/states/<entity_id>` | `get_states`, `subscribe_entities` |
| Available actions and fields | `GET /api/services` | `get_services` |
| History | `GET /api/history/period/<ISO time>?filter_entity_id=<id>` | `history/history_during_period` |
| Render a template (admin) | `POST /api/template` with `{"template": "…"}` (read-only) | `render_template` |
| Check configuration (admin) | `POST /api/config/core/check_config` | `validate_config` for a trigger, condition or action snippet |
| Error log (admin) | `GET /api/error_log` | Settings → System → Logs |
| Automation run details | — | Automation editor → Traces (download the trace JSON) |

`POST /api/template` and `check_config` are POSTs but change nothing; say so when the permission prompt asks.

## Change (after approval)

- **Action call:** `POST /api/services/<domain>/<action>` with `{"entity_id": "…", …}`; add `?return_response` only for actions that return data (others answer 400). Over WebSocket: `call_service` with `target` (`entity_id`, `device_id`, `area_id`, `floor_id`, `label_id`).
- **Never** `POST /api/states/<entity_id>` to "switch" something: it only overwrites what Home Assistant displays until the integration's next update.
- **Reload before restart:** `automation.reload`, `script.reload`, `template.reload`, `homeassistant.reload_core_config`, or a config entry reload; a full restart only when the change needs it, after a passing configuration check (`skills/ha-configuration`).
- **Supervisor CLI** (Home Assistant OS and Supervised only): `ha core check`, `ha backups new --name <name>`, `ha core update --backup`, `ha core restart`; each change command needs approval.

## MCP

Home Assistant's own **MCP Server** integration (since 2025.2; endpoint `/api/mcp`, OAuth) offers LLM APIs: **Assist** sees only entities exposed to voice and cannot do anything administrative; the **Home Assistant** API is for admins and is not limited to exposed entities. Prefer the Assist API for device control, and keep locks, alarm panels and garage doors unexposed unless the user wants voice control of them. Community MCP servers (for example `homeassistant-ai/ha-mcp`) add configuration tools; use their read-only mode and backups when available.
