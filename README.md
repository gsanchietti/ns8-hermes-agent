# ns8-hermes-agent

`ns8-hermes-agent` is currently a renamed NethServer 8 module scaffold with Hermes-specific image names and wrapper containers. The checked-in code provides a small rootless module service, an embedded admin UI scaffold, smarthost discovery plumbing, and build and test assets.

Older docs in this repository may still describe a larger Hermes manager architecture. Use the checked-in tree as the source of truth.

## Current code state

- module image built by `build-images.sh` and labeled with three dependent wrapper images under `containers/`
- custom actions: `configure-module`, `get-configuration`, and `destroy-module`
- `configure-module` validates an `agents` payload, stores `AGENTS_LIST` in `agents.env`, sets the Traefik path route at `/hermes-agent`, and starts or restarts the module service
- `get-configuration` returns the configured agents parsed from `AGENTS_LIST`
- smarthost discovery helper plus a `smarthost-changed` reload-or-restart handler
- embedded Vue 2 and Vue CLI admin UI with `status`, `settings`, and `about` views; `settings` now manages agents from the NS8 module UI
- Robot Framework tests under `tests/`

## Repository layout

- `imageroot/` contains the current NS8 actions, helper script, event handler, and user systemd unit.
- `ui/` contains the embedded Vue 2 and Vue CLI application.
- `containers/` contains thin component image wrappers for Hermes, Gateway, and OpenViking.
- `tests/` contains the Robot Framework suite and Python test dependencies.

See `STRUCTURE.md` for a file-by-file map.

## Build

Build the module image and the component images with:

```bash
bash build-images.sh
```

The script uses:

- `REPOBASE`, default `ghcr.io/nethserver`
- `IMAGETAG`, default `latest`

`IMAGETAG` is normalized so branch names that contain `/` still produce valid image tags.

## UI development

The module UI lives in `ui/` and is built into `/ui` inside the module image.

For local UI work:

```bash
cd ui
yarn install
yarn serve
```

To build the production UI bundle:

```bash
cd ui
yarn install
yarn build
```

If your shell does not already provide it, set `NODE_OPTIONS=--openssl-legacy-provider` before running the UI toolchain.

## Install

Instantiate the module with:

    add-module ghcr.io/nethserver/hermes-agent:latest 1

The output of the command will return the instance name.
Output example:

    {"module_id": "hermes-agent1", "image_name": "hermes-agent", "image_url": "ghcr.io/nethserver/hermes-agent:latest"}

## Configure

Let's assume that the hermes-agent instance is named `hermes-agent1`.

The current settings UI and `configure-module` action manage an array of
agents. Each agent contains:

- `id`: integer starting from `1`
- `name`: user-defined string with allowed characters `[A-Za-z ]`
- `role`: one of `default` or `developer`
- `status`: one of `start` or `stop`; it is accepted in the JSON payload for
  UI compatibility, but only `id`, `name`, and `role` are persisted today

The persisted runtime value is stored in `agents.env` as:

    AGENTS_LIST=1:Foo Bar:developer,2:Alice:default

Example:

    api-cli run module/hermes-agent1/configure-module --data '{"agents":[{"id":1,"name":"Foo Bar","role":"developer","status":"start"}]}'

The above command will:
- validate and store the agent roster in `agents.env`
- configure the Traefik path route for `/hermes-agent`
- start or restart the module service so the updated env file is injected into the container

Read the current configuration with:

    api-cli run module/hermes-agent1/get-configuration --data '{}'

Example output:

    {"agents": [{"id": 1, "name": "Foo Bar", "role": "developer", "status": "start"}]}

`status` is currently synthesized by `get-configuration` and defaults to
`start` for every persisted agent until runtime status handling is implemented.

Send a test HTTP request to the hermes-agent backend service:

    curl http://127.0.0.1/hermes-agent/

## Smarthost setting discovery

Some settings are discovered from Redis rather than passed through the
`configure-module` input. The helper `imageroot/bin/discover-smarthost`
writes `smarthost.env` before the module service starts, and the event handler
`imageroot/events/smarthost-changed/10reload_services` reloads or restarts the service when
cluster smarthost settings change.

The agent roster uses a separate `agents.env` file because `smarthost.env` is
fully owned by the smarthost discovery helper.

This is the current scaffold behavior and can be replaced if the module grows
beyond the template.

## Uninstall

To uninstall the instance:

    remove-module --no-preserve hermes-agent1

## Testing

Run the module test with:


    ./test-module.sh <NODE_ADDR> ghcr.io/nethserver/hermes-agent:latest

The checked-in test suite is written with [Robot Framework](https://robotframework.org/).

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org]((https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project