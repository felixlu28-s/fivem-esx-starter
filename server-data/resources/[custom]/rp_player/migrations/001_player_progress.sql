CREATE TABLE IF NOT EXISTS rp_player_progress (
    identifier VARCHAR(60) NOT NULL,
    running_meters INT UNSIGNED NOT NULL DEFAULT 0,
    training_seconds INT UNSIGNED NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (identifier),
    CONSTRAINT chk_rp_running_meters CHECK (running_meters <= 100000000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
