# ui Guidelines

- This subtree is the embedded NS8 admin UI. Preserve the current stack unless the task is a frontend migration: Vue 2, Vue CLI, Vue Router, Vuex, Carbon, and `@nethserver/ns8-ui-lib`.
- The settings page is now Hermes-only. Keep it focused on listing agents, creating and editing agents, deleting agents, and toggling start or stop state.
- The backend payload for `configure-module` is only `{ "agents": [...] }`. There are no hidden fields, shared gateway flags, or OpenViking settings to preserve.
- `get-configuration` returns only `{ "agents": [...] }`, where `status` is the desired persisted state and `runtime_status` is the current systemd runtime state. Only round-trip `status` back to `configure-module`.
- When user-facing text changes, update `public/metadata.json` and the translation files together.