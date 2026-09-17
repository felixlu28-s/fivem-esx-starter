# rp_characters

Character selection and creation for ESX Legacy. The server derives the player identifier from `source`, validates every field, checks ownership on selection, and uses parameterized oxmysql queries.

Status: prototype after ESX login, not an ESX multicharacter implementation. Selection currently only records a resource-local ID; it does not switch ESX identity, accounts, inventory or spawn the character. See `docs/project-status.md` at the repository root for remaining requirements.

## Setup

1. Run `migrations/001_create_characters.sql` against the configured database.
2. Start resources in this order: `spawnmanager`, `baseevents`, `oxmysql`, `ox_lib`, `esx_lib`, `es_extended`, `skinchanger`, `rp_core`, `rp_characters`, `rp_ui`.
3. Use `/characters` in-game to open the central NUI.

`rp_ui` depends on `rp_characters` for its NUI callback bridge. `rp_characters` does not depend on `rp_ui`, so the domain dependency graph remains acyclic.
