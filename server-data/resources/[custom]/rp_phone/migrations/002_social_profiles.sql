-- Run once after 001_phone_apps.sql. Existing public identities and all social
-- content retain their IDs. Phone numbers, private contacts and photos stay put.
CREATE TABLE IF NOT EXISTS rp_phone_social_profiles (
 id INT UNSIGNED NOT NULL AUTO_INCREMENT,
 owner INT UNSIGNED NOT NULL, slot TINYINT UNSIGNED NOT NULL,
 handle VARCHAR(24) NOT NULL, name VARCHAR(60) NOT NULL,
 bio VARCHAR(160) NOT NULL DEFAULT '', created INT UNSIGNED NOT NULL, nonce VARCHAR(80) DEFAULT NULL,
 PRIMARY KEY(id), UNIQUE KEY social_owner_slot(owner,slot), UNIQUE KEY social_handle(handle), UNIQUE KEY social_create_nonce(owner,nonce),
 CONSTRAINT rp_phone_social_owner FOREIGN KEY(owner) REFERENCES rp_phone_profiles(id),
 CHECK(slot BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO rp_phone_social_profiles (id,owner,slot,handle,name,bio,created)
 SELECT id,id,1,COALESCE(handle,CONCAT('citizen',id)),name,bio,UNIX_TIMESTAMP() FROM rp_phone_profiles;
CREATE TABLE IF NOT EXISTS rp_phone_social_accounts (
 owner INT UNSIGNED NOT NULL, slots TINYINT UNSIGNED NOT NULL DEFAULT 1,
 active INT UNSIGNED DEFAULT NULL,
 PRIMARY KEY(owner), CONSTRAINT rp_phone_social_account_owner FOREIGN KEY(owner) REFERENCES rp_phone_profiles(id),
 CONSTRAINT rp_phone_social_account_active FOREIGN KEY(active) REFERENCES rp_phone_social_profiles(id),
 CHECK(slots BETWEEN 1 AND 5)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
INSERT IGNORE INTO rp_phone_social_accounts (owner,active) SELECT owner,id FROM rp_phone_social_profiles WHERE slot=1;
ALTER TABLE rp_phone_posts DROP FOREIGN KEY rp_phone_posts_ibfk_1,
 ADD CONSTRAINT rp_phone_social_post_author FOREIGN KEY(author) REFERENCES rp_phone_social_profiles(id);
ALTER TABLE rp_phone_likes DROP FOREIGN KEY rp_phone_likes_ibfk_2,
 ADD CONSTRAINT rp_phone_social_like_profile FOREIGN KEY(profile) REFERENCES rp_phone_social_profiles(id);
ALTER TABLE rp_phone_comments DROP FOREIGN KEY rp_phone_comments_ibfk_2,
 ADD CONSTRAINT rp_phone_social_comment_author FOREIGN KEY(author) REFERENCES rp_phone_social_profiles(id);
ALTER TABLE rp_phone_follows DROP FOREIGN KEY rp_phone_follows_ibfk_1, DROP FOREIGN KEY rp_phone_follows_ibfk_2,
 ADD CONSTRAINT rp_phone_social_follower FOREIGN KEY(follower) REFERENCES rp_phone_social_profiles(id),
 ADD CONSTRAINT rp_phone_social_target FOREIGN KEY(target) REFERENCES rp_phone_social_profiles(id);
