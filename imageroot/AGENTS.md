# imageroot Guidelines

- This subtree is the installed NS8 module payload. Keep it aligned to the checked-in Hermes-only implementation.
- There is no OpenViking runtime, no hidden backend runtime, no shared target, and no `AGENTS_LIST` registry anymore.
- The runtime contract is simple: one configured agent equals one metadata file, one generated env file, one generated secrets file, one Hermes home directory, one `hermes-agent@<id>.service`, and one `hermes-agent-<id>` container.
- Preserve the NS8 action model already used here: numbered executable action steps, JSON stdin for actions, JSON stdout for reads, and schema files beside the actions.
- `environment` is shared NS8 state. Merge only managed keys and preserve core-managed values such as `HERMES_AGENT_HERMES_IMAGE`.
- Keep module-wide secrets in `secrets.env`. Keep generated per-agent container secrets in `agent_<id>_secrets.env`.
- Keep shared smarthost discovery in `discover-smarthost`, and keep per-agent file generation in `sync-agent-runtime`. If you change generated file names or payload fields, update the actions, event handler, unit file, tests, and docs together.
- Do not inject the shared `environment` file directly into containers. Containers should consume the generated per-agent env files only.