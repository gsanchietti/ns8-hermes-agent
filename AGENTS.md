# Repository Guidelines

- Keep changes within the current scaffold unless the task explicitly expands scope: NS8 module runtime under `imageroot/`, embedded admin UI under `ui/`, thin wrapper images under `containers/`, and basic CI and test scaffolding.
- Prefer the smallest coherent change and keep related docs, tests, and build files in sync.
- Put long reference material in normal docs, not in AGENTS. Use `README.md` for current status and operator-facing behavior, `STRUCTURE.md` for file maps, and `NS8-MODULE.md` for NS8 lifecycle details.
- Only `imageroot/` and `ui/` currently justify local AGENTS files. Do not add more unless a subtree gains genuinely different conventions.
- When asked to commit, use Conventional Commits.
- before editing actions, event handlers, build-image scripts, or the UI, browse for documentation following in NS8_RESOURCE_MAP.md
- before making choices related to hermes-agents containers, environment, memory, volumes and setup, search for documentation in HERMES_RESOURCE_MAP.md
- After code changes that may affect documentation, invoke the `docs-maintainer` custom agent to review checked-in Markdown files. Keep `README.md` current for humans, and keep `AGENTS.md` files plus `STRUCTURE.md` current for agents and implementation accuracy.
- use the `committer` agent for all commits
