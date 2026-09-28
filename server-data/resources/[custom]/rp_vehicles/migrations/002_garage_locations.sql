CREATE TABLE IF NOT EXISTS rp_vehicle_garages (
    id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    payload LONGTEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    revision INT UNSIGNED NOT NULL DEFAULT 1,
    deleted TINYINT UNSIGNED NOT NULL DEFAULT 0,
    updated_by VARCHAR(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_garage_active (deleted),
    CONSTRAINT ck_garage_payload CHECK (JSON_VALID(payload)),
    CONSTRAINT ck_garage_deleted CHECK (deleted IN (0,1))
) ENGINE=InnoDB;
