# rp_characters

Character selection and creation for ESX Legacy. The server derives the player identifier from `source`, validates every field, checks ownership on selection, and uses parameterized oxmysql queries.

## Setup

1. Run `migrations/001_create_characters.sql` against the configured database.
2. Start resources in this order: `oxmysql`, `ox_lib`, `es_extended`, `rp_core`, `rp_characters`, `rp_ui`.
3. Use `/characters` in-game to open the central NUI.

`rp_ui` depends on `rp_characters` for its NUI callback bridge. `rp_characters` does not depend on `rp_ui`, so the domain dependency graph remains acyclic.