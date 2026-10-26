---
name: ha-dashboards
version: 1.0.0
description: 'Designs and builds Home Assistant dashboards: sections view, cards, tile features, visibility conditions, YAML versus UI mode, mobile and wall-tablet layouts, and dashboards per room or person. Use for "build a Home Assistant dashboard", "Lovelace", "HA card", "dashboard for the tablet".'
metadata:
  category: home-automation
---

# HA Dashboards

A dashboard answers the questions people in the house ask most often, in the fewest taps. Design the task first (who looks at it, what they need to see or do in one tap); then build with the cards the user's version offers.

## Rules

1. **Purpose per dashboard:** a household overview, one per wall tablet or room, and an admin dashboard for diagnostics. The auto-generated Overview stays as a fallback.
2. **Sections view** (the default view type) for new dashboards: one section per area or topic, a heading card on top, tile cards with features (brightness, cover position, climate modes) instead of custom cards where possible.
3. **Real entities only,** from the instance (`skills/ha-live-instance`); prefer area- and label-based layouts so new devices fit in.
4. **Visibility conditions** (user, screen width, state) instead of duplicate dashboards; since 2026.10 card visibility uses the same conditions as the automation editor.
5. **Security devices** (locks, alarm panels, garage doors) on a dashboard get a confirmation where the card supports it, and not on shared wall tablets without the user's decision.
6. **Custom cards** from HACS only when a built-in card cannot do it; each one is code from a third party that can break on update: name the risk.
7. **Accessible and readable:** icons with names, enough contrast in light and dark themes, large tap targets on tablets (at least 48 px), information never by color alone.

## Modes

- **UI mode** (default): the user edits in the browser; give the YAML of a card or section to paste via "Edit in YAML".
- **YAML mode** (`lovelace:` with `mode: yaml` or extra dashboards under `dashboards:`) when the configuration lives in git; the UI editor is then read-only for that dashboard.

## Deliverable

The section layout (areas, cards per section), the YAML for each new card or the whole view, the entities it uses, and screenshots after the user applied it (phone and tablet width).
