# ns8-hermes-agent

`ns8-hermes-agent` is currently a renamed NethServer 8 module scaffold with Hermes-specific image names and wrapper containers. The checked-in code provides a small rootless module service, an embedded admin UI scaffold, smarthost discovery plumbing, and build and test assets.

Older docs in this repository may still describe a larger Hermes manager architecture. Use the checked-in tree as the source of truth.

## Current code state

- module image built by `build-images.sh` and labeled with three dependent wrapper images under `containers/`
- custom actions: `configure-module`, `get-configuration`, and `destroy-module`
- `configure-module` validates an `agents` payload, stores `AGENTS_LIST` in `environment`, generates per-agent env files, secrets files, and OpenViking config files, and reconciles per-agent systemd targets
- each started agent gets its own rootless Podman pod managed by systemd, with `openviking`, `hermes`, and `hermes-gateway` containers
- each started agent also gets two internal named Podman volumes: one mounted at Hermes `/opt/data` for gateway state, and one mounted at OpenViking `/app/data` for context storage
- those named volumes are internal to the module for now; the image does not yet declare `org.nethserver.volumes` for NS8 disk-placement integration
- `get-configuration` returns the configured agents parsed from `AGENTS_LIST` and reports actual runtime status from systemd
- smarthost discovery helper plus a `smarthost-changed` handler that refreshes active per-agent targets
- embedded Vue 2 and Vue CLI admin UI with `status`, `settings`, and `about` views; `settings` now manages agents from the NS8 module UI
- the current implementation does not publish an external HTTP route
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
- `status`: one of `start` or `stop`; it is persisted and used to decide whether
    the per-agent systemd target should be running

The persisted runtime value is stored in `environment` as:

        AGENTS_LIST=1:Foo Bar:developer:start,2:Alice User:default:stop

Example:

    api-cli run module/hermes-agent1/configure-module --data '{"agents":[{"id":1,"name":"Foo Bar","role":"developer","status":"start"}]}'

The above command will:
- validate and store the agent roster in `environment`
- generate `agent-<id>.env`, `agent-<id>_secrets.env`, and `agent-<id>_openviking.conf` files for each agent
- generate `systemd.env` with only the controlled image variables needed by systemd units
- start or stop the matching `hermes-agent@<id>.target` instances based on the saved status
- create or clean the matching per-agent named volumes as containers are started or removed

Read the current configuration with:

    api-cli run module/hermes-agent1/get-configuration --data '{}'

Example output:

    {"agents": [{"id": 1, "name": "Foo Bar", "role": "developer", "status": "start"}]}

`status` is returned from the actual systemd-backed runtime state, not only from
the desired configuration.

Started agents enable a templated user target named `hermes-agent@<id>.target`.
That target brings up a Podman pod plus three container services:

- `hermes-agent-pod@<id>.service`
- `hermes-agent-openviking@<id>.service`
- `hermes-agent-hermes@<id>.service`
- `hermes-agent-gateway@<id>.service`

The persistent storage contract is currently:

- `hermes-agent-gateway@<id>.service` mounts `hermes-agent-hermes-data-<id>` at `/opt/data`
- `hermes-agent-openviking@<id>.service` mounts `hermes-agent-openviking-data-<id>` at `/app/data`
- `hermes-agent-openviking@<id>.service` also bind-mounts the generated `agent-<id>_openviking.conf` to `/app/ov.conf`
- the idle `hermes-agent-hermes@<id>.service` container remains ephemeral in the current scaffold

The gateway wrapper now keeps the upstream Hermes Docker entrypoint, so first
start still bootstraps `/opt/data` with default `.env`, `config.yaml`,
`SOUL.md`, and bundled skills.

## Smarthost setting discovery

Some settings are discovered from Redis rather than passed through the
`configure-module` input. The helper `imageroot/bin/discover-smarthost`
writes public SMTP settings into `environment` and `SMTP_PASSWORD` into
`secrets.env`. The helper `imageroot/bin/sync-agent-runtime` then copies only
the agent-specific runtime data into `agent-<id>.env`,
`agent-<id>_secrets.env`, and `agent-<id>_openviking.conf` so each pod consumes
only its own runtime files. The event handler
`imageroot/events/smarthost-changed/10reload_services` refreshes active agent
targets when cluster smarthost settings change.

`environment` is shared with NS8 core, so module writers must merge their
managed keys instead of overwriting the file. `secrets.env` is reserved for
sensitive values that should not live in the shared environment file, and
`systemd.env` is generated as a controlled subset for the systemd units.

This is the current scaffold behavior and can be replaced if the module grows
beyond the template.

## Uninstall

To uninstall the instance:

    remove-module --no-preserve hermes-agent1

## Testing

Run the module test with:


    ./test-module.sh <NODE_ADDR> ghcr.io/nethserver/hermes-agent:latest

The checked-in test suite is written with [Robot Framework](https://robotframework.org/) and
currently validates per-agent runtime file generation, actual runtime status
from `get-configuration`, per-agent target plus container service state, Podman
pod presence, named volume creation, persistence across target restart,
reconfiguration cleanup, and module removal.

## UI translation

Translated with [Weblate](https://hosted.weblate.org/projects/ns8/).

To setup the translation process:

- add [GitHub Weblate app](https://docs.weblate.org/en/latest/admin/continuous.html#github-setup) to your repository
- add your repository to [hosted.weblate.org]((https://hosted.weblate.org) or ask a NethServer developer to add it to ns8 Weblate project