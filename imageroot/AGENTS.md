# imageroot Guidelines

- This subtree is the installed NS8 module payload. Keep it aligned to the checked-in per-agent pod implementation, not to older single-service scaffold docs or broader aspirational manager designs.
- The implemented runtime here includes `configure-module`, `get-configuration`, `destroy-module`, smarthost discovery, generated per-agent env files, one event handler, a shared Python runtime helper, and templated user systemd units for per-agent pods.
- Treat route, service, and restart wiring as one change set. If you change route path, service name, container port, env-file usage, or reload behavior, update the corresponding action scripts, event handlers, unit files, and tests or docs together.
- Follow the NS8 conventions already present here: numbered executable action and event steps, JSON stdin and stdout for Python actions, and schema files beside actions when payloads are defined.
- Keep shell helpers thin and explicit. Put behavior in action logic and documented module rules, not in opaque shell branching.
- Ensure event handlers target the same unit names that are actually shipped in this tree.
- `environment` is a shared NS8 state file. When module actions update it, merge only the managed keys and preserve existing core-managed variables such as the service image environment variables created from `org.nethserver.images`.
- Do not inject the shared `environment` file directly into containers. Generate `systemd.env` for controlled systemd inputs and per-agent `agent-<id>.env` plus `agent-<id>_secrets.env` for Podman `--env-file` usage.
- Keep secrets in `secrets.env` and the generated `agent-<id>_secrets.env` files; public module settings such as `AGENTS_LIST` and non-secret smarthost values belong in `environment`.
- If `configure-module` changes persisted agent fields, update the `AGENTS_LIST` serializer and parser in `pypkg/hermes_agent_runtime.py` together, and keep the action entrypoints aligned with that shared helper.
- `status` is persisted in `AGENTS_LIST` as the desired state, but `get-configuration` must continue to report the actual runtime status derived from systemd.