# Structure

This document maps the current checked-in layout. It does not describe planned
Hermes manager components that are not yet present in the tree.

## Root files

- `AGENTS.md`: repo-wide instructions.
- `README.md`: current project status and usage notes.
- `STRUCTURE.md`: this file.
- `build-images.sh`: builds the module image and the three wrapper images.
- `test-module.sh`: runs the Robot Framework module test.
- `renovate.json`: Renovate configuration.

## `imageroot/`

`imageroot/` is copied into the installed NS8 module image.

- `AGENTS.md`: local runtime instructions.

### `imageroot/actions/`

- `configure-module/20configure`: configures the Traefik path route for `/hermes-agent`.
- `configure-module/80start_services`: creates `smarthost.env` and enables `hermes-agent.service`.
- `configure-module/validate-input.json`: current input schema for `configure-module`; it is empty.
- `get-configuration/20read`: returns an empty JSON object.
- `get-configuration/validate-output.json`: output schema for `get-configuration`.
- `destroy-module/20destroy`: removes the module Traefik route.

### `imageroot/bin/`

- `discover-smarthost`: reads cluster smarthost settings and writes `smarthost.env`.

### `imageroot/events/`

- `smarthost-changed/10reload_services`: reloads or restarts the module service when cluster smarthost settings change.

### `imageroot/systemd/user/`

- `kickstart.service`: the only checked-in user unit file; its current contents start the hermes-agent Podman service.

## `containers/`

Thin component wrapper images used by the module image labels:

- `containers/hermes/Containerfile`: wrapper around the upstream Hermes runtime image.
- `containers/gateway/Containerfile`: wrapper for Hermes gateway mode.
- `containers/openviking/Containerfile`: wrapper around the upstream OpenViking image.

## `ui/`

The embedded admin UI currently uses Vue 2 and Vue CLI.

- `AGENTS.md`: local UI instructions.
- `README.md`: short UI development note.
- `package.json`: UI dependencies and scripts such as `serve`, `build`, and `watch`.
- `Containerfile`: UI image build file.
- `container-entrypoint.sh`: runs `yarn install` and then `watch` or `build`.
- `babel.config.js`, `vue.config.js`: UI build configuration.
- `public/metadata.json`: module metadata used by the UI shell.
- `public/i18n/`: translation files.
- `src/App.vue`: top-level embedded shell layout.
- `src/router/index.js`: router with `status`, `settings`, and `about` views.
- `src/store/index.js`: Vuex store for embedded module context.
- `src/views/`: page scaffolds for status, settings, and about.
- `src/components/`: side menu components.
- `src/i18n/index.js`: runtime language loading.
- `src/styles/`: shared Carbon utility styles.
- `src/assets/`: static UI assets.

## `tests/`

- `__init__.robot`: Robot Framework initialization file.
- `kickstart.robot`: current install, configure, HTTP, and remove test flow.
- `pythonreq.txt`: Python dependencies used by the test runner.
