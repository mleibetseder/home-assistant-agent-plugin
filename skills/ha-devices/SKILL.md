---
name: ha-devices
version: 1.0.0
description: 'Chooses and sets up Home Assistant devices: local-first device integrations, Zigbee (ZHA or Zigbee2MQTT), Matter and Thread, and ESPHome YAML with encrypted API and OTA. Use for "add a Zigbee device", "Matter pairing", "ESPHome config", "which device should I buy".'
metadata:
  category: home-automation
---

# HA Devices

Prefer devices and integrations that keep working without the internet. Check what the user already runs (coordinator, Thread border router, ESPHome version) before recommending anything new.

## Choosing an integration

The integration's IoT class (on its documentation page) says how it talks to the device:

| IoT class | Meaning | Preference |
|---|---|---|
| `local_push` | Device reports changes itself, on the local network | Best |
| `local_polling` | Home Assistant asks the device regularly | Good; do not lower the poll interval without need |
| `cloud_push` / `cloud_polling` | Through the vendor's cloud | Only when no local option exists; breaks without internet, may rate-limit |
| `assumed_state` | No feedback from the device | Avoid for anything important |

## Zigbee

- **ZHA** (built in) or **Zigbee2MQTT** (separate app plus MQTT broker, wider device support). Do not switch an existing network without a migration plan: devices must be re-paired.
- Coordinator on a USB 2.0 port with a shielded extension cable, away from USB 3 ports, SSDs and Wi-Fi routers; keep the default channel unless there is interference.
- A strong mesh needs mains-powered routers spread through the house; battery devices do not route.

## Matter and Thread

- Matter in Home Assistant runs through the Matter Server (an app on Home Assistant OS); it needs IPv6 and, for Thread devices, a Thread border router. Pair through the Home Assistant Companion app.
- A Matter device can be shared with several ecosystems (multi-admin); say which ecosystem stays primary.

## ESPHome

```yaml
esphome:
  name: office-sensor

esp32:
  board: esp32dev

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

api:
  encryption:
    key: !secret office_sensor_api_key

ota:
  - platform: esphome
    encryption:   # empty: reuses the API encryption key (ESPHome 2026.9+)

logger:
```

- Every secret through `!secret` in the ESPHome `secrets.yaml`, never inline; the API encryption key is a 32-byte base64 value, one per device.
- OTA passwords are discouraged since ESPHome 2026.9: an empty `encryption:` under `ota:` reuses the API key, and the plain-password fallback is announced for removal. Migrating a device that has an OTA password takes two flashes; follow the steps on esphome.io for the user's ESPHome version.
- Update one device first, then the rest; keep a USB cable or serial access for devices in hard-to-reach places in case an update fails.
- Lambdas (C++) are code: keep them short and get larger ones reviewed by someone other than their author before flashing.

## Safety

Relays switching mains voltage, heaters, valves and locks: wiring and fail-safe defaults (what happens on reboot or Wi-Fi loss, `restore_mode`) are part of the design; mains wiring is for a qualified electrician.
