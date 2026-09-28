-- Configured ESX shops are imported once by the resource, retaining their original venue IDs.
-- Tombstones prevent a deleted configured shop from reappearing after a restart.
CREATE TABLE IF NOT EXISTS rp_commerce_shops (
    id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    revision INT UNSIGNED NOT NULL DEFAULT 1,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload)),
    deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_shops_active (deleted),
    CONSTRAINT chk_shops_revision CHECK (revision > 0),
    CONSTRAINT chk_shops_deleted CHECK (deleted IN (0,1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
