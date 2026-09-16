CREATE TABLE IF NOT EXISTS rp_characters (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    identifier VARCHAR(96) NOT NULL,
    firstname VARCHAR(32) NOT NULL,
    lastname VARCHAR(32) NOT NULL,
    dateofbirth DATE NOT NULL,
    gender ENUM('m', 'f') NOT NULL,
    height SMALLINT UNSIGNED NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_rp_characters_identifier (identifier),
    CONSTRAINT chk_rp_characters_height CHECK (height BETWEEN 120 AND 230)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;