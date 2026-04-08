# imageroot Guidelines

- This subtree is the installed NS8 module payload. Keep it aligned to the current scaffold implementation, not to aspirational multi-agent manager docs.
- The implemented runtime here is small: `configure-module`, `get-configuration`, `destroy-module`, smarthost discovery, one event handler, and one user systemd unit. Do not assume agent CRUD, per-agent pods, or Python manager services exist unless the task explicitly adds them.
- Treat route, service, and restart wiring as one change set. If you change route path, service name, container port, env-file usage, or reload behavior, update the corresponding action scripts, event handlers, unit files, and tests or docs together.
- Follow the NS8 conventions already present here: numbered executable action and event steps, JSON stdin and stdout for Python actions, and schema files beside actions when payloads are defined.
- Keep shell helpers thin and explicit. Put behavior in action logic and documented module rules, not in opaque shell branching.
- Ensure event handlers target the same unit names that are actually shipped in this tree.
- Keep `agents.env` separate from `smarthost.env`: `discover-smarthost` owns `smarthost.env` and will overwrite it.
- If `configure-module` changes persisted agent fields, update both the `AGENTS_LIST` serializer in `configure-module/20configure` and the parser in `get-configuration/20read` together.
- `status` is accepted in the JSON payload but is not persisted in `AGENTS_LIST`; `get-configuration` currently synthesizes `start` for each stored agent.