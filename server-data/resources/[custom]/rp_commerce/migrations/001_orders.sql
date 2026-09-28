-- Item receipts remain in rp_inventory_operations; money remains owned by ESX.
-- Uncertain ESX debit outcomes are held for review, never guessed/refunded twice.
CREATE TABLE IF NOT EXISTS rp_commerce_orders (
    actor VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    request_id VARCHAR(55) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    fingerprint TEXT NOT NULL,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload)),
    status ENUM('intent', 'paid', 'completed', 'cancelled') NOT NULL,
    review_note VARCHAR(500) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (actor, request_id),
    KEY pending_actor (actor, status),
    KEY created_index (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
