CREATE TABLE IF NOT EXISTS rp_commerce_weaponshops (
    id VARCHAR(48) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    revision INT UNSIGNED NOT NULL DEFAULT 1,
    payload LONGTEXT NOT NULL CHECK (JSON_VALID(payload)),
    deleted TINYINT(1) NOT NULL DEFAULT 0,
    updated_by VARCHAR(100) NOT NULL,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id), KEY idx_weaponshops_active (deleted),
    CONSTRAINT chk_weaponshops_revision CHECK (revision > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Deliberately no automatic weapon licence grant. This demo is unlicensed until configured.
-- Soft deletion means running this migration again cannot resurrect a removed shop.
INSERT IGNORE INTO rp_commerce_weaponshops (id, payload, updated_by) VALUES (
 'ammunation_pillbox',
 '{"label":"Ammu-Nation · Pillbox","coords":{"x":22.10,"y":-1106.85,"z":29.80,"bucket":0},"license":false,"npc":{"pos":{"x":22.62,"y":-1105.58,"z":28.80},"heading":160.0,"model":"s_m_y_ammucity_01","scenario":"WORLD_HUMAN_STAND_IMPATIENT"},"prices":{},"displays":[{"id":"pistol","catalog":"pistol","type":"counter","pos":{"x":22.13,"y":-1106.05,"z":30.12},"rot":{"x":90.0,"y":0.0,"z":160.0},"heading":160.0,"scale":1.0,"height":0.0},{"id":"rifle","catalog":"rifle","type":"wall","pos":{"x":18.68,"y":-1107.18,"z":30.50},"rot":{"x":0.0,"y":0.0,"z":250.0},"heading":250.0,"scale":1.0,"height":0.0}]}',
 'migration:002'
);
