---
name: ha-automations
version: 1.0.0
description: 'Writes, fixes and reviews Home Assistant automations, scripts and blueprints in the syntax of the user''s version: triggers, conditions, actions, modes, waits, error handling and trace debugging. Use for "write an automation", "my automation does not fire", "blueprint", "HA script".'
metadata:
  category: home-automation
---

# HA Automations

Automations react (triggers → conditions → actions); scripts are reusable action sequences with fields; blueprints are automations or scripts with inputs. Check the version first (`skills/ha-live-instance`) and use real entity IDs.

## Syntax by version

| Since | Use | Instead of |
|---|---|---|
| 2024.8 | `action: light.turn_on` | `service:` (still works) |
| 2024.10 | `triggers:`, `conditions:`, `actions:` and `- trigger: state` | `trigger:`/`condition:`/`action:` lists and `platform: state` (still work) |
| 2026.7 | Purpose-specific triggers and conditions, for example `- trigger: motion.detected` with `target: {area_id: hallway}` and `options: {for: …, behavior: each\|first\|all}` | Device triggers and state triggers on sensors, where a purpose-specific one exists |

2026.7 also renamed some purpose-specific keys (for example `battery.low` → `battery.became_low`, `vacuum.docked` → `vacuum.returned_to_dock`); check the release notes of the user's version for renamed keys before reusing older YAML. Older versions: write the classic `trigger: state` / `numeric_state` form.

## Rules

1. **Entities, not devices.** Target `entity_id`, `area_id`, `floor_id` or `label_id`; `device_id` and device triggers break when a device is re-added.
2. **Pick the mode on purpose:** `single` (default; a second run is dropped with a warning), `restart` for motion lights and timers that must start over, `queued` for steps that must all run in order, `parallel` for independent runs. Set `max_exceeded: silent` only when dropping is expected.
3. **Native before template:** `state`, `numeric_state`, `time`, `sun`, `zone` and purpose-specific triggers and conditions before `template` ones; helpers (timer, schedule, threshold, min_max) before long templates (`skills/ha-templates`).
4. **Survive restarts and `unavailable`:** `for:` timers do not survive a restart; long delays belong in a `timer` helper. Guard `numeric_state` and state triggers against `unavailable`/`unknown` (`not_from:`/`not_to:`). Give every `wait_for_trigger` and `wait_template` a `timeout` and handle `wait.completed`.
5. **No loops:** an automation that changes the entity it triggers on needs a condition or `trigger.to_state.context` check.
6. **Errors:** a missing target is skipped with a warning, not an error; `continue_on_error: true` covers runtime errors of that step only, not configuration or template errors; `enabled: false` turns one step off.
7. **One automation, one purpose,** with an `alias`, a `description` and `id` (UI-editable); trigger `id:` for branching with `choose:` (the UI shows this as the "Triggered by" condition since 2026.10).

## Scripts and blueprints

- Script `fields:` document inputs; `required` and `default` only shape the UI, so templates still need `| default(…)`. `script.turn_on` does not wait; call the script directly (`action: script.<name>`) to wait for it, and pass values under `data:`.
- `response_variable:` only on actions that return data (it makes other actions fail); read it in the next steps.
- Blueprints: `blueprint:` with `name`, `domain` (`automation`, `script` or `template`), `homeassistant: min_version:` and typed `input:` selectors; `!input` is a YAML tag, so use it through `variables:` inside templates.

## Debug

1. Open the automation's **Traces**: which trigger fired, which condition stopped it, what each action returned.
2. Not in the trace at all: trigger never fired; check the state history of the trigger entity and the mode (`single` dropped it).
3. Test a trigger, condition or action snippet with `validate_config` or in Tools → YAML before saving.

## Example (2024.10+ syntax)

```yaml
- id: hallway_motion_light
  alias: Hallway light on motion
  description: On with motion after sunset, off 2 minutes after motion stops.
  mode: restart
  triggers:
    - trigger: state
      entity_id: binary_sensor.hallway_motion
      to: "on"
  conditions:
    - condition: sun
      after: sunset
  actions:
    - action: light.turn_on
      target:
        entity_id: light.hallway
    - wait_for_trigger:
        - trigger: state
          entity_id: binary_sensor.hallway_motion
          to: "off"
          for: "00:02:00"
      timeout: "01:00:00"
    - action: light.turn_off
      target:
        entity_id: light.hallway
```
