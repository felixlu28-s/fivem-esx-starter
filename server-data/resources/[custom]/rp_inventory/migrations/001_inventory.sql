CREATE TABLE IF NOT EXISTS rp_inventory_stores (
    id VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL PRIMARY KEY,
    kind VARCHAR(16) CHARACTER SET ascii NOT NULL,
    label VARCHAR(80) NOT NULL,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload)),
    context LONGTEXT NOT NULL CHECK (JSON_VALID(context)),
    legacy_backup LONGTEXT NULL,
    revision BIGINT UNSIGNED NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY kind_index (kind)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rp_inventory_operations (
    actor VARCHAR(160) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    request_id VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    fingerprint TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (actor, request_id), KEY created_index (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Locks and revision checks happen inside one transaction, before either write.
-- Keep operation receipts: deleting them shortens the replay-protection window.
DELIMITER $$
CREATE OR REPLACE PROCEDURE rp_inventory_commit(
    IN p_actor VARCHAR(160), IN p_request VARCHAR(80), IN p_fingerprint TEXT,
    IN p_id1 VARCHAR(160), IN p_rev1 BIGINT, IN p_data1 LONGTEXT,
    IN p_id2 VARCHAR(160), IN p_rev2 BIGINT, IN p_data2 LONGTEXT
)
main: BEGIN
    DECLARE v_revision BIGINT DEFAULT NULL;
    DECLARE v_receipt TEXT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    -- Caller sorts IDs, so every transfer takes locks in the same order.
    IF p_id2 IS NOT NULL AND BINARY p_id1 >= BINARY p_id2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid_lock_order';
    END IF;
    SELECT revision INTO v_revision FROM rp_inventory_stores WHERE id = p_id1 FOR UPDATE;
    SELECT fingerprint INTO v_receipt FROM rp_inventory_operations
        WHERE actor = p_actor AND request_id = p_request;
    IF v_receipt IS NOT NULL THEN
        IF BINARY v_receipt <> BINARY p_fingerprint THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'request_reused';
        END IF;
        COMMIT;
        SELECT 'replayed' AS status;
        LEAVE main;
    END IF;
    IF v_revision IS NULL OR v_revision <> p_rev1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'stale_inventory';
    END IF;
    IF p_id2 IS NOT NULL THEN
        SET v_revision = NULL;
        SELECT revision INTO v_revision FROM rp_inventory_stores WHERE id = p_id2 FOR UPDATE;
        IF v_revision IS NULL OR v_revision <> p_rev2 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'stale_inventory';
        END IF;
    END IF;
    UPDATE rp_inventory_stores SET payload = p_data1, revision = revision + 1 WHERE id = p_id1;
    IF p_id2 IS NOT NULL THEN
        UPDATE rp_inventory_stores SET payload = p_data2, revision = revision + 1 WHERE id = p_id2;
    END IF;
    INSERT INTO rp_inventory_operations (actor, request_id, fingerprint) VALUES (p_actor, p_request, p_fingerprint);
    COMMIT;
    SELECT 'committed' AS status;
END$$
DELIMITER ;
