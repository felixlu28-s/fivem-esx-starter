-- Forward-only: preserves the old rp_characters prototype and existing ESX users.
CREATE TABLE IF NOT EXISTS rp_character_accounts (
    identifier VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    slots TINYINT UNSIGNED NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier),
    CONSTRAINT chk_rp_account_slots CHECK (slots BETWEEN 1 AND 8)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rp_character_slots (
    account_identifier VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    slot TINYINT UNSIGNED NOT NULL,
    esx_identifier VARCHAR(60) NOT NULL,
    last_position LONGTEXT NULL,
    last_seen TIMESTAMP NULL DEFAULT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account_identifier, slot),
    UNIQUE KEY uq_rp_character_esx (esx_identifier),
    CONSTRAINT fk_rp_character_account FOREIGN KEY (account_identifier)
        REFERENCES rp_character_accounts (identifier) ON DELETE RESTRICT,
    CONSTRAINT chk_rp_character_slot CHECK (slot BETWEEN 1 AND 8),
    CONSTRAINT chk_rp_character_position CHECK (last_position IS NULL OR JSON_VALID(last_position))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
