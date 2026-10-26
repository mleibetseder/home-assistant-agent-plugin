---
name: ha-configuration
version: 1.0.0
description: 'Changes Home Assistant configuration safely: configuration.yaml, packages, secrets, configuration check, reload or restart, backups, recorder size, updates and breaking changes. Use for "edit configuration.yaml", "update Home Assistant", "database too big", "HA backup".'
metadata:
  category: home-automation
---

# HA Configuration

Every configuration change follows one path: back up → edit → check → reload (or restart) → verify. Version and entities come from the instance (`skills/ha-live-instance`).

## Safe change path

1. **Back up** before a live change: Settings → System → Backups, `ha backups new --name before-<change>` (Home Assistant OS) or the `backup.create_automatic` action. Backups are encrypted by default; the user needs the emergency-kit key to restore. External MariaDB or PostgreSQL databases are not in the backup. When the configuration is in git, a commit is the undo for YAML, not for `.storage/` or the database.
2. **Edit YAML,** never files in `.storage/` (they are UI state that Home Assistant rewrites). Two-space indentation; keep comments.
3. **Check:** Tools → YAML → Check configuration, `ha core check`, or `POST /api/config/core/check_config`. A failing check stops here.
4. **Reload the smallest scope** (Tools → YAML: automations, scripts, template entities, core configuration, a single config entry); restart only when the integration needs it. Never restart with a failing check.
5. **Verify** the entities and the log (`GET /api/error_log`), and tell the user how to undo.

## Structure

- **Packages** keep one feature together (its helpers, automations, template entities): `homeassistant: packages: !include_dir_named packages`; package file names must be unique; `auth_providers` stays in `configuration.yaml`.
- `!secret name` for every password, token, API key or URL with credentials, stored in `secrets.yaml`; never print or commit `secrets.yaml` (add it to `.gitignore`).
- `!include`, `!include_dir_list`, `!include_dir_merge_list`, `!include_dir_named`, `!include_dir_merge_named` to split large files.
- **Organise** with areas, floors (since 2024.4), labels and categories; target areas, floors and labels in automations so new devices join without edits. Entity IDs can be renamed since 2026.8; renaming silently breaks YAML, templates and dashboards that still use the old ID, so search the configuration for every reference first.

## Updates

1. Read the **breaking changes** section of every release between the installed and the target version (monthly releases, plus patch releases).
2. Back up (or `ha core update --backup`), update, check the log and the repairs list (Settings → System → Repairs).
3. Roll back by restoring the backup made on the older version; a downgrade without restore does not undo database migrations. A restore can take a long time: never cut power during it.

## Recorder (database size)

- Defaults: `purge_keep_days: 10`, `commit_interval: 5`. Exclude chatty entities with `exclude:` (`entities`, `entity_globs`, `domains`) instead of keeping everything; `recorder.purge` and `recorder.purge_entities` clean up.
- Keep free disk space at least the size of the database (more for repairs); on SD cards, high write rates shorten their life, so prefer SSD.

## Version-dependent names

Since 2026.2 add-ons are called **Apps**; since 2026.8 Developer Tools is called **Tools**. Use the names of the user's version.
