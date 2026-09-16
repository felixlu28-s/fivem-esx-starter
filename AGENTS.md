# Codex project instructions

## Mission

Build and maintain a production-quality FiveM roleplay server based on ESX Legacy. Gameplay resources use Lua. Browser UI uses React and TypeScript. Keep the repository as one monorepo while respecting FiveM resource boundaries.

## Architecture

- Treat `es_extended`, `ox_lib`, and `oxmysql` as external dependencies. Never patch vendor code unless the user explicitly requests a temporary diagnostic patch.
- Put project-owned resources in `server-data/resources/[custom]/` and prefix them with `rp_`.
- Prefer domain-sized resources such as `rp_vehicles` or `rp_jobs`; do not create a resource for every tiny feature and do not create one giant server resource.
- Put shared utilities and cross-resource contracts in `rp_core`. Keep business rules in the resource that owns the domain.
- Keep the full-screen NUI centralized in `rp_ui`. Other resources communicate with it through documented client events or exports.
- Use exports for synchronous capabilities and events for facts that already happened. Namespace every public event, callback, command, and export.
- Keep dependencies acyclic. Domain resources may depend on `rp_core` and `rp_ui`; `rp_core` must not depend on domain resources.

## Security rules

- The server is authoritative. Never trust client-provided prices, rewards, permissions, inventory counts, coordinates, entity ownership, or database identifiers.
- Validate type, range, state, permissions, ownership, distance, and rate limits for every network-facing action.
- Derive the player from FiveM `source`; never accept a player ID from a client as proof of identity.
- Use parameterized oxmysql queries. Never concatenate user-controlled values into SQL.
- Return minimal data to clients and never expose secrets, identifiers, or internal database rows unnecessarily.
- Add cleanup for `playerDropped`, resource stop, and failed asynchronous operations where relevant.

## Lua conventions

- Use Lua 5.4 syntax supported by current FiveM artifacts.
- Prefer `local` scope, early returns, small functions, explicit names, and tables with named keys for records.
- Keep files focused: `client/`, `server/`, and `shared/`. A file should own one cohesive concern.
- Avoid global state. If long-lived state is necessary, own it in one module and expose a narrow API.
- Do not busy-loop. Every thread must wait appropriately, and event-driven code is preferred.
- Use `joaat` or FiveM hash literals where appropriate; do not recompute constant hashes in hot paths.

## React and TypeScript conventions

- Keep TypeScript strict and avoid `any`. Validate NUI message payloads before using them.
- Route all game-to-browser messages through the typed envelope in `rp_ui/web/src/lib/nui.ts`.
- Every NUI callback must always send a response, including error paths.
- Preserve browser-development fallbacks so the UI can run with Vite outside FiveM.
- Build to `rp_ui/web/dist`; never hand-edit generated files.

## Workflow

1. Read the nearest `AGENTS.md` and the relevant resource manifest before changing code.
2. Trace client, server, database, and NUI boundaries before implementation.
3. Make the smallest coherent change and preserve unrelated user edits.
4. Run `npm run check` from the repository root after code changes.
5. If the NUI changed, also run `npm run ui:build` and verify that `web/dist/index.html` exists.
6. If runtime verification requires FXServer and it is unavailable, state exactly what remains unverified.

## Database changes

- Put forward-only SQL migrations in the owning resource under `migrations/`.
- Use sortable names such as `001_create_vehicles.sql`.
- Include keys, indexes, constraints, and explicit character set choices.
- Never silently delete production data. Destructive migrations require an explicit warning and rollback plan.

## Definition of done

- Resource dependencies and start order are documented.
- Network entry points are validated server-side.
- Lua and TypeScript checks pass.
- New configuration has safe defaults and is documented.
- No secrets, generated dependency folders, caches, or local database volumes are committed.

## Custom agent

Use the project-scoped `fivem_builder` agent for bounded FiveM architecture, implementation, or review tasks when delegation is explicitly requested. Parallel agents should not edit overlapping files.
