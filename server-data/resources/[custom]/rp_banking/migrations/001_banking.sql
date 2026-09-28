-- Journal only. Money remains owned/saved by ESX, never by these tables.
CREATE TABLE IF NOT EXISTS rp_banking_transactions (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    actor VARCHAR(96) COLLATE utf8mb4_bin NOT NULL,
    target VARCHAR(96) COLLATE utf8mb4_bin NULL,
    request_id VARCHAR(64) COLLATE utf8mb4_bin NOT NULL,
    fingerprint TEXT NOT NULL,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload)),
    status ENUM('intent','completed','review','cancelled') NOT NULL DEFAULT 'intent',
    review_note VARCHAR(450) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY actor_request (actor, request_id),
    KEY actor_status (actor, status), KEY target_status (target, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rp_banking_history (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id VARCHAR(96) COLLATE utf8mb4_bin NOT NULL,
    reference VARCHAR(96) COLLATE utf8mb4_bin NULL,
    kind VARCHAR(24) NOT NULL,
    amount BIGINT NOT NULL,
    balance BIGINT UNSIGNED NOT NULL,
    counterparty VARCHAR(100) NOT NULL DEFAULT '',
    note VARCHAR(120) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id), UNIQUE KEY character_reference (character_id, reference),
    KEY character_history (character_id, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
