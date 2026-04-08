# NS8 Module Reference — ns8-hermes-agent

This document describes the current checked-in NS8 module implementation for
`ns8-hermes-agent`. Treat the repository tree as the source of truth.

## Scope

The current module is a rootless NS8 application scaffold that manages a stored
roster of agents. Each configured agent can own an isolated Podman pod managed
by systemd user units.

The current runtime includes:

- `configure-module`, `get-configuration`, and `destroy-module`
- smarthost discovery and one `smarthost-changed` event handler
- generated per-agent env and secrets files
- templated user systemd units for one pod per agent
- three wrapper container images: Hermes, Hermes gateway, and OpenViking
- an embedded Vue 2 admin UI
- a Robot Framework smoke test focused on the per-agent runtime contract

The current runtime does not publish a Traefik route or expose an HTTP endpoint.

## NS8 Concepts Used Here

### Module instance

Each installed instance gets a module identifier such as `hermes-agent1`.

### Actions

Actions live under `imageroot/actions/<action-name>/` and run numbered steps in
lexical order.

### Systemd user units

Because the module is rootless, long-running services are managed with
`systemctl --user` under the module user account.

### Events

Event handlers live under `imageroot/events/<event-name>/` and are composed of
numbered executable steps.

## Repository Components Relevant To NS8

- `build-images.sh`: builds the module image and three wrapper images
- `imageroot/actions/`: action implementations for configure, read, and destroy
- `imageroot/bin/`: runtime helper scripts
- `imageroot/pypkg/`: shared Python runtime helpers
- `imageroot/systemd/user/`: templated systemd target and service units
- `ui/`: embedded NS8 admin UI
- `tests/`: Robot Framework smoke suite

## Image Build And Packaging

`build-images.sh` builds four images:

| Image | Purpose |
|------|---------|
| `ghcr.io/nethserver/hermes-agent` | Main NS8 module image with `imageroot/` and the compiled UI bundle. |
| `ghcr.io/nethserver/hermes-agent-hermes` | Thin wrapper around the upstream Hermes image. |
| `ghcr.io/nethserver/hermes-agent-gateway` | Hermes gateway wrapper image. |
| `ghcr.io/nethserver/hermes-agent-openviking` | OpenViking wrapper image. |

The module image currently sets these relevant NS8 labels:

- `org.nethserver.rootfull=0`
- `org.nethserver.images=<wrapper image list>`

The practical effect is:

- the module runs rootless
- the core pulls the additional wrapper images on install and update
- the pulled image URLs are exposed as environment variables such as
  `HERMES_AGENT_HERMES_IMAGE`, `HERMES_AGENT_GATEWAY_IMAGE`, and
  `HERMES_AGENT_OPENVIKING_IMAGE`

The current image does not declare `org.nethserver.volumes`, so the per-agent
named volumes created by the runtime stay internal to the module and are not
currently surfaced for NS8 additional-disk assignment.

The current image does not request a TCP port and does not request Traefik route
authorizations.

## Lifecycle Summary

```text
add-module
  -> create-module (core only)
       - pulls the module image and the wrapper images
       - installs imageroot and UI assets
  -> configure-module
       - validates and persists the agent roster in environment
       - discovers smarthost settings
      - writes systemd.env plus per-agent env, secrets, and OpenViking config files
       - starts or stops per-agent systemd targets based on desired status
  -> module running
       - get-configuration returns the stored roster with actual runtime status
       - smarthost-changed refreshes active per-agent targets only
  -> destroy-module
       - stops and disables per-agent targets
      - removes pods, per-agent named volumes, and generated runtime files
       - core removes the rootless module state and service user
```

## Actions

### `configure-module`

**Path**: `imageroot/actions/configure-module/`

Accepted payload shape:

```json
{
  "agents": [
    {
      "id": 1,
      "name": "Foo Bar",
      "role": "developer",
      "status": "start"
    }
  ]
}
```

Each agent must contain:

- `id`: integer greater than or equal to `1`
- `name`: non-empty string matching `^[A-Za-z ]+$`
- `role`: `default` or `developer`
- `status`: `start` or `stop`

Steps:

| Step | File | Purpose |
|------|------|---------|
| 20 | `20configure` | Validates the payload and persists `AGENTS_LIST` into `environment`. |
| 80 | `80start_services` | Delegates lifecycle reconciliation to `start-agent-services`. |

The persisted roster format is:

```text
AGENTS_LIST=1:Foo Bar:developer:start,2:Alice User:default:stop
```

The stored `status` is the desired state. The runtime status returned later by
`get-configuration` is derived from systemd.

### `get-configuration`

**Path**: `imageroot/actions/get-configuration/`

| Step | File | Purpose |
|------|------|---------|
| 20 | `20read` | Parses `AGENTS_LIST` from `environment` and returns the roster with actual runtime status from systemd. |

Example output:

```json
{
  "agents": [
    {
      "id": 1,
      "name": "Foo Bar",
      "role": "developer",
      "status": "start"
    },
    {
      "id": 2,
      "name": "Alice User",
      "role": "default",
      "status": "stop"
    }
  ]
}
```

`start` means all required services for that agent pod are active. Otherwise the
action returns `stop`.

### `destroy-module`

**Path**: `imageroot/actions/destroy-module/`

| Step | File | Purpose |
|------|------|---------|
| 20 | `20destroy` | Stops and disables all known per-agent targets, removes pods and per-agent named volumes, and deletes generated per-agent runtime files. |

### Base actions used but not customized

The current repository does not customize:

- `create-module`
- `get-status`
- `update-module`

No `update-module.d/` scripts are currently shipped.

## Runtime State Files

The module runtime uses these state files:

- `environment`: shared NS8 state; stores `AGENTS_LIST` and public smarthost
  settings
- `secrets.env`: shared sensitive smarthost values such as `SMTP_PASSWORD`
- `systemd.env`: generated controlled subset of environment values used only by
  systemd units
- `agent-<id>.env`: per-agent public runtime env file
- `agent-<id>_secrets.env`: per-agent sensitive runtime env file
- `agent-<id>_openviking.conf`: per-agent OpenViking server config bind-mounted
  into the OpenViking container

Containers load only the per-agent env and secrets files. They do not load the
shared `environment` or shared `secrets.env` directly. The OpenViking container
also bind-mounts its generated `agent-<id>_openviking.conf` file at `/app/ov.conf`.

## Helper Scripts And Shared Runtime Code

### `discover-smarthost`

**Path**: `imageroot/bin/discover-smarthost`

This helper:

- connects to the local Redis replica
- reads cluster SMTP settings through the NS8 agent helpers
- writes public SMTP values into `environment`
- writes `SMTP_PASSWORD` into `secrets.env`
- removes the legacy `smarthost.env` file if present

### `sync-agent-runtime`

**Path**: `imageroot/bin/sync-agent-runtime`

This helper:

- reads the stored agent roster
- writes `systemd.env` from controlled image variables
- writes `agent-<id>.env`, `agent-<id>_secrets.env`, and
  `agent-<id>_openviking.conf` for each stored agent
- removes stale per-agent runtime files for deleted agents

### `start-agent-services`

**Path**: `imageroot/bin/start-agent-services`

This helper:

- refreshes smarthost data
- regenerates runtime env files
- reloads the user systemd daemon
- starts or stops `hermes-agent@<id>.target` based on the desired state
- cleans stale pods and per-agent named volumes for deleted agents

### `reload-agent-services`

**Path**: `imageroot/bin/reload-agent-services`

This helper refreshes smarthost data and restarts only currently active agent
targets.

### Shared helper module

**Path**: `imageroot/pypkg/hermes_agent_runtime.py`

This module centralizes:

- agent validation
- `AGENTS_LIST` serialization and parsing
- runtime-file generation
- per-agent named volume naming and cleanup
- systemd unit naming
- runtime status checks
- cleanup helpers

## Systemd User Units

The checked-in unit templates under `imageroot/systemd/user/` are:

- `hermes-agent@.target`: umbrella target for one agent stack
- `hermes-agent-pod@.service`: creates and removes the Podman pod
- `hermes-agent-openviking@.service`: runs the OpenViking container in the pod
- `hermes-agent-hermes@.service`: runs the Hermes container in the pod
- `hermes-agent-gateway@.service`: runs the gateway container in the pod

Starting `hermes-agent@1.target` creates a rootless pod named
`hermes-agent-1` and starts the three containers inside it.

The container services use `systemd.env` only for controlled image variables and
inject per-agent runtime data through:

- `%S/state/agent-%i.env`
- `%S/state/agent-%i_secrets.env`

The current persistent storage layout is:

- `hermes-agent-gateway@.service` mounts the per-agent named volume
  `hermes-agent-hermes-data-%i` at `/opt/data`
- `hermes-agent-openviking@.service` mounts the per-agent named volume
  `hermes-agent-openviking-data-%i` at `/app/data`
- `hermes-agent-openviking@.service` bind-mounts
  `%S/state/agent-%i_openviking.conf` at `/app/ov.conf`
- `hermes-agent-hermes@.service` remains ephemeral in the current scaffold and
  does not mount the shared Hermes state volume

The gateway wrapper preserves the upstream Hermes Docker entrypoint, so the
Hermes data volume is bootstrapped on first start with default `.env`,
`config.yaml`, `SOUL.md`, and bundled skills.

## Events

### `smarthost-changed`

**Path**: `imageroot/events/smarthost-changed/`

| Step | File | Purpose |
|------|------|---------|
| 10 | `10reload_services` | Delegates to `reload-agent-services` so only active agent targets are refreshed when shared SMTP settings change. |

## Embedded Admin UI

The module includes a Vue 2 based NS8 admin UI under `ui/`.

Current UI behavior relevant to the backend:

- the `Settings` view reads data through `get-configuration`
- the `Settings` view writes the full agent roster through `configure-module`
- the UI already models `start` and `stop` status per agent
- the backend now persists desired status and returns actual runtime status

## Testing

The checked-in smoke test is `tests/kickstart.robot`.

It validates this flow:

1. install the module
2. configure two agents with mixed `start` and `stop` state
3. verify per-agent runtime files exist
4. verify `get-configuration` reports actual runtime status for both agents
5. verify the per-agent target, pod service, container services, and Podman pod
  state for the active agent, and verify inactive target plus absent pod state
  for the stopped agent
6. verify the active agent creates the expected named volumes and preserves
  Hermes and OpenViking data across `hermes-agent@<id>.target` restart
7. reconfigure the roster to remove one agent and start the other
8. verify cleanup of the removed agent runtime and named volumes
9. remove the module

## What Is Not Implemented In This Tree

The current repository does not implement these behaviors:

- no Traefik route management
- no HTTP endpoint published by the module itself
- no custom `create-module` or `get-status` steps
- no backup, restore, clone, or transfer-state helpers
- no firewall management hooks
- no LDAP or user-domain integration

If the module grows beyond this runtime, update this document from the checked-in
tree before describing additional lifecycle details.