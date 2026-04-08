# ui Guidelines

- This subtree is the embedded NS8 admin UI. Preserve the current stack unless frontend migration is the task: Vue 2, Vue CLI, Vue Router, Vuex, Carbon, and `@nethserver/ns8-ui-lib`.
- Keep the embedded-shell pattern: `App.vue` reads context from `window.parent`, task execution goes through the NS8 UI task helpers, and routing and state live under `src/router/` and `src/store/`.
- Use the existing Yarn-based toolchain and build assumptions. Keep compatibility with `yarn.lock`, `vue.config.js`, and the legacy `NODE_OPTIONS=--openssl-legacy-provider` requirement used locally and in CI.
- The current UI is a small multi-view scaffold (`status`, `settings`, `about`), not the one-page Hermes manager described in stale docs. Extend or clean up the existing scaffold directly instead of introducing a second frontend architecture.
- When backend action names, payloads, metadata, or user-facing text change, update the corresponding view code, `public/metadata.json`, and translation files together.