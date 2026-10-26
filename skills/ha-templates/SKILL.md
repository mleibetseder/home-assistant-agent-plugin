---
name: ha-templates
version: 1.0.0
description: 'Writes and fixes Home Assistant Jinja templates and template entities: safe defaults, availability, trigger-based template sensors, the modern template: integration (legacy platform: template is removed). Use for "template sensor", "Jinja in Home Assistant", "template error".'
metadata:
  category: home-automation
---

# HA Templates

Templates compute values from states with Jinja. Test every template against the live instance before saving (`POST /api/template` or Tools → Template, `skills/ha-live-instance`).

## Rules

1. **Safe accessors:** `states('sensor.x')`, `state_attr('climate.x', 'temperature')`, `is_state('lock.x', 'locked')`, `has_value('sensor.x')`. Never `states.sensor.x.state`: it errors when the entity is missing.
2. **States are strings.** Convert with a default: `states('sensor.power') | float(0)`, `| int(0)`; without a default the template fails on `unknown` or `unavailable`. `int` truncates; round on purpose (`| round(1)`).
3. **Handle missing data explicitly:** prefer an `availability:` template that makes the entity `unavailable` over silently reporting 0.
4. **Templates are the last resort.** Use a native trigger or condition, or a helper (threshold, min_max, derivative, utility_meter, statistics) when one fits; a UI helper is easier to maintain.
5. **Time:** `now()`, `today_at('07:30')`, `as_timestamp()`, `as_datetime()`; templates using `now()` re-render once a minute, not every second.

## Template entities

The legacy `platform: template` under `sensor:`/`binary_sensor:` was deprecated in 2025.12 and **removed in 2026.6**. Use the top-level `template:` integration (UI template helpers cover the simple cases):

```yaml
template:
  - sensor:
      - name: House power
        unique_id: house_power
        unit_of_measurement: W
        device_class: power
        state_class: measurement
        state: >
          {{ states('sensor.grid_power') | float(0) + states('sensor.solar_power') | float(0) }}
        availability: >
          {{ has_value('sensor.grid_power') and has_value('sensor.solar_power') }}
  - triggers:
      - trigger: time_pattern
        hours: "/1"
    sensor:
      - name: Outdoor temperature hourly
        unique_id: outdoor_temperature_hourly
        unit_of_measurement: "°C"
        state: "{{ states('sensor.outdoor_temperature') | float(0) }}"
```

- Always set `unique_id` (makes the entity editable in the UI).
- **Trigger-based** blocks (`triggers:`, optional `conditions:` and `actions:`) update only when their trigger fires, not when referenced states change, and they restore their state after a restart.
- `device_class`, `state_class` and `unit_of_measurement` decide whether long-term statistics and the energy dashboard can use the sensor.

## Debug

- Error "float got invalid input 'unavailable' … no default was specified": add a default or an `availability` template.
- Value never changes: a trigger-based template waits for its trigger; a state-based one only listens to entities it read in the last render.
- Logs show template errors with the entity ID; Tools → Template shows which entities a template listens to.
