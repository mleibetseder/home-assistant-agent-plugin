---
name: ha-integration-dev
version: 1.0.0
description: 'Develops Home Assistant custom integrations in Python around a device or cloud API client: manifest, config flow, DataUpdateCoordinator, quality scale, pytest tests and HACS publishing. Use for "custom integration", "custom component", "HACS integration", "config flow".'
metadata:
  category: engineering
---

# HA Integration Development

Builds a custom integration the way Home Assistant core builds its own. Developer docs moved to contributors.home-assistant.io; read the current page before using an API you are unsure of. Write a failing test first for every behaviour and bug fix, then the code; get an independent review (another agent or a person) before release.

## Layout

```text
custom_components/<domain>/
  __init__.py        # async_setup_entry / async_unload_entry
  manifest.json
  config_flow.py
  coordinator.py
  sensor.py ...      # one module per platform
  strings.json, translations/en.json
tests/               # pytest-homeassistant-custom-component
```

## Rules

1. **manifest.json** for custom integrations needs `domain`, `name`, `version`, `codeowners`, `documentation`, `iot_class`; add `issue_tracker`, `integration_type`, `config_flow: true` and pinned `requirements` (exact versions of a published library that does the device protocol; no protocol code in the integration).
2. **Config flow** only (no YAML setup for new integrations): `async_step_user`; `await self.async_set_unique_id(<stable device or account ID>)` then `self._abort_if_unique_id_configured()`. Never an IP address or host name as unique ID. Discovery steps confirm with the user before creating an entry; support `reauth` and `reconfigure`.
3. **Data fetching** through one `DataUpdateCoordinator` per config entry: pass `config_entry`, set a sensible `update_interval` (do not poll faster than the device or API allows), raise `UpdateFailed` on errors, call `await coordinator.async_config_entry_first_refresh()` in setup, and store it as `entry.runtime_data` with a typed alias `type MyConfigEntry = ConfigEntry[MyCoordinator]`.
4. **Entities:** `CoordinatorEntity`, `_attr_has_entity_name = True`, stable `unique_id`, `device_info`, translated names, correct `device_class`, `state_class` and units; mark diagnostic and config entities with `entity_category`.
5. **Async only:** no blocking I/O in the event loop; use the library's async client or `hass.async_add_executor_job`.
6. **Secrets:** credentials live in the config entry, never in logs (redact them in diagnostics with `async_redact_data`).

## Quality scale

Home Assistant's integration quality scale (Bronze, Silver, Gold, Platinum) is a good checklist for custom integrations too: Bronze covers config flow, unique IDs, tests of the config flow and documented setup; Silver adds high test coverage, error handling and reauthentication; Gold adds diagnostics, discovery and translations; Platinum strict typing and async dependencies. Track it in `quality_scale.yaml` and mark each rule `done`, `todo` or `exempt` with a reason; never claim a rule is met without checking it.

## Tests

- `pytest-homeassistant-custom-component` provides the `hass` fixture and `MockConfigEntry`; mock the device library at its boundary, never a real device or cloud account.
- Test the config flow (success, cannot connect, invalid auth, already configured), setup and unload, coordinator failure (`UpdateFailed` → entities unavailable) and each platform's states.

## Publish (HACS)

One integration per repository under `custom_components/<domain>/`, a `hacs.json`, brand icon, GitHub releases with the version in `manifest.json`; the README documents setup through the UI and the data the integration sends anywhere.
