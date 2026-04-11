# NS8 Module Notes

This document summarizes the current checked-in NS8 behavior for `ns8-hermes-agent`.

## Overview

`ns8-hermes-agent` is now a simple Hermes-only NS8 module.

- No OpenViking runtime
- No hidden system agent
- No shared backend API service
- One configured agent equals one runtime service and one container

The implementation keeps the module lifecycle explicit:

- `create-module`: initialize module state only
- `configure-module`: validate agent input, persist one metadata file per agent, and reconcile services
- `get-configuration`: report configured agents, preserving desired status and exposing actual runtime state separately
- `destroy-module`: stop services and remove generated state

## Images

The module publishes:

- `ghcr.io/nethserver/hermes-agent`: the NS8 module image
- `ghcr.io/nethserver/hermes-agent-hermes`: the Hermes wrapper image

No other wrapper images are used.

## Input model

`configure-module` accepts:

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

Rules:

- `id` must be an integer greater than or equal to `1`
- `name` accepts letters and spaces only
- `role` must match the shipped role list
- `status` is `start` or `stop`

## Output model

`get-configuration` returns:

```json
{
  "agents": [
    {
      "id": 1,
      "name": "Foo Bar",
      "role": "developer",
      "status": "start",
      "runtime_status": "start"
    }
  ]
}
```

`status` is the persisted desired state.
`runtime_status` is derived from `systemctl --user is-active hermes-agent@<id>.service`.

## State files

Module-wide state:

- `environment`
- `secrets.env`

Per-agent state:

- `agents/<id>/metadata.json`
- `agents/<id>/home/SOUL.md`
- `agents/<id>/home/.env`
- `agent_<id>.env`
- `agent_<id>_secrets.env`

Shared SMTP values come from `discover-smarthost`:

- public SMTP keys are merged into `environment`
- `SMTP_PASSWORD` is written into `secrets.env`

`sync-agent-runtime` copies the relevant shared SMTP values into each generated per-agent env file.

## Service model

The shipped unit is:

- `imageroot/systemd/user/hermes-agent@.service`

For agent `1`, the runtime looks like:

- systemd service: `hermes-agent@1.service`
- container name: `hermes-agent-1`
- Hermes home bind mount: `%S/state/agents/1/home` mounted at `/opt/data`

There is no target unit and no companion service graph.

## Template seeding

The module seeds two files into each agent home when they do not already exist:

- `SOUL.md`, from `imageroot/templates/SOUL.md.in`
- `.env`, from `imageroot/templates/home.env.in`

Placeholder replacement is performed with `sed` inside `sync-agent-runtime`.

## Action flow

### `create-module`

- loads JSON input and ignores its content
- persists `TIMEZONE`
- creates `agents/` and `secrets.env`
- runs `discover-smarthost`
- does not create or start any agent runtime

### `configure-module`

- validates the submitted agent list
- writes one `metadata.json` file per agent
- removes deleted agents
- runs `discover-smarthost`
- runs `sync-agent-runtime`
- reloads the user systemd manager
- enables and starts `hermes-agent@<id>.service` only for agents with `status: start`
- disables and stops services for agents with `status: stop`

### `destroy-module`

- disables and stops every known `hermes-agent@<id>.service`
- removes every `hermes-agent-<id>` container if present
- removes generated per-agent env files and state directories

## Testing contract

The checked-in tests cover:

- install with zero active agent services
- configure with zero agents
- create one started agent and verify service/container/files
- stop the agent and verify inactive runtime
- remove the agent and verify cleanup
- remove the module and verify instance cleanup