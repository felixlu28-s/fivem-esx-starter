# Codex project instructions

## Mission

Build and maintain a production-quality FiveM roleplay server based on ESX Legacy. Gameplay resources use Lua. Browser UI uses React and TypeScript. Keep the repository as one monorepo while respecting FiveM resource boundaries.

## Mandatory ESX compatibility — applies to every task

- Before implementing or changing a system, inspect the installed ESX Legacy version and the official ESX resource/API for that feature. Prefer extending standard functionality over inventing a competing replacement. Record the chosen integration and compatibility limits in the domain README.
- Keep vendor resources unmodified. Put custom behavior and React interfaces in project-owned resources; preserve standard ESX exports, callbacks, events, job/grade names and persistence contracts required by third-party scripts.
- ESX owns the active character, its primary job, money/accounts, inventory and other standard player state. Use xPlayer APIs for online changes (for example setJob); do not maintain competing authoritative copies or update online users rows behind ESX's back.
- Persistent gameplay data belongs to xPlayer.getIdentifier()/xPlayer.identifier (the full ESX character identifier, e.g. char1:license), never the raw account license or temporary server ID. Only explicitly account-wide features such as the permitted character count use the account identifier.
- Keep the official ESX multicharacter contract: Multichar enabled, server-owned charN slot prefix for esx:onPlayerJoined, separate users rows, normal ESX player loading/saving. A custom selector or creator must not bypass this lifecycle. Test two characters on one account for isolated gameplay state.
- Model extra faction memberships as character-scoped extensions. They do not overwrite the primary ESX job. Document that third-party scripts using only xPlayer.job need an explicit adapter for secondary memberships; never promise universal compatibility.
- Inspect authoritative state through current ESX APIs/exports. Do not assume tables copied from getSharedObject at resource startup stay current after ESX replaces them.
- Cross-resource ESX player tables are snapshots, not shared mutable objects. Compare full identifiers plus session generations across awaits; do not compare exported table identity or assign fields on snapshots. Use the official client/server spawn handshake (`esx:onPlayerSpawn`) so ESX itself owns its spawned flag and save eligibility.
- Inventory uses ESX Legacy's official custom-inventory bridge with `rp_inventory` as its sole provider (`provide 'ox_inventory'`). Use standard xPlayer item APIs for single-store operations and the provider's atomic transfer API for transfers; check return values. `rp_inventory_stores` is the durable authority behind those APIs; `users.inventory` is only ESX's save mirror and must never be re-imported once a provider row exists. Do not start a second inventory provider, write item counts directly, or implement remove-then-add transfers. The alias implements the documented ESX bridge subset, not the complete ox_inventory API. Keep `inventory:accounts` set to `[]`; money stays in ESX accounts. New weapons are inventory items, not legacy ESX loadout entries. See the resource README before adding containers, items, shops or weapon scripts.

## Resource architecture

- Start `rp_inventory` before `esx_addoninventory`: the unchanged ESX addon calls the provider's `RegisterStash` export at startup. Registered stashes require an explicit server-owned location before opening; preserve job/character permissions and never silently replace legacy addon stock. See `rp_inventory/README.md` for the supported adapter contract.

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
- Every project-owned local human NPC must use `rp_core:rpProtectPed` / `rpReleasePed`. Registration automatically enables the shared greeting/look/gesture system; configure its profile and stable per-resource NPC key with `rpConfigureNpc`, and pause it during editors or dedicated scenes. Reuse `rp_core/shared/npcs.lua` and its README instead of writing separate shop/job greeting loops. NPC owners retain their base idle/scenario and streaming/placement lifecycle.
- NPC placement stores a ground/sole anchor. Start player-position floor probes at player Z + 0.5, but never store that probe lift as standing height. `initialHeightOffset` defaults to zero: the former +0.5 default caused hovering and was superseded by foot alignment. Reject surfaces above the standing player's feet (e.g. counters); probes must be bounded. Derive the model-specific root-to-sole height from the live foot bones with a small sole clearance, not the model bounding box. Apply a bounded, cancellable skeleton alignment after creation/model replacement; never continuously snap or overwrite saved/manual positions. Restart the configured idle immediately after model replacement. Raycast placement uses the selected surface. Cancel pending placement/animation/model loads on cleanup.
- Use `joaat` or FiveM hash literals where appropriate; do not recompute constant hashes in hot paths.

## React and TypeScript conventions

- Reusable keyboard-driven GTA interaction menus use `rp_nativeui` and the central `rp_ui` renderer; see its README before integrating. NativeUI banners always use the mint-green theme, including root menus, submenus and previews. All UIs prevent text selection outside editable fields through the shared selection guard; preserve text editing and inventory drag-and-drop.

- **Mandatory UI standard for every task:** Follow [docs/ui-design.md](docs/ui-design.md) for every new or changed surface. The character creator and repository GTA references define the visual direction: compact, flat separated menu sections, transparent game surroundings, restrained mint accents, off-white selected rows with dark text, and consistent SVG icons. Reuse `rp_ui/web/src/design.css` tokens and `components/UiIcon.tsx`; do not introduce an independent theme, full-screen dimming veil, large rounded dashboard cards, or fixed-pixel game UI. Preserve readable scaling through 4K, accessible labels/focus and browser Studio previews. Domain styles own layout; shared tokens own appearance.

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
