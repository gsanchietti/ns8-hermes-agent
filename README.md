# ns8-hermes-agent

`ns8-hermes-agent` is currently a renamed NethServer 8 module scaffold with Hermes-specific image names and wrapper containers. The checked-in code provides a small rootless module service, an embedded admin UI scaffold, smarthost discovery plumbing, and build and test assets.

Older docs in this repository may still describe a larger Hermes manager architecture. Use the checked-in tree as the source of truth.

## Current code state

- module image built by `build-images.sh` and labeled with three dependent wrapper images under `containers/`
- custom actions: `configure-module`, `get-configuration`, and `destroy-module`
- `configure-module` sets a Traefik path route at `/hermes-agent` and starts the module service
- `get-configuration` currently returns an empty JSON object
- smarthost discovery helper plus a `smarthost-changed` reload handler
- embedded Vue 2 and Vue CLI admin UI with `status`, `settings`, and `about` views
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

The current input schema is empty, so the action can be invoked with `{}`:

Example:

    api-cli run module/hermes-agent1/configure-module --data '{}'

The above command will:
- configure the Traefik path route for `/hermes-agent`
- start the module service

Send a test HTTP request to the hermes-agent backend service:

    curl http://127.0.0.1/hermes-agent/

## Smarthost setting discovery

Some settings are discovered from Redis rather than passed through the
`configure-module` input. The helper `imageroot/bin/discover-smarthost`
writes `smarthost.env` before the module service starts, and the event handler
`imageroot/events/smarthost-changed/10reload_services` reloads the service when
cluster smarthost settings change.

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