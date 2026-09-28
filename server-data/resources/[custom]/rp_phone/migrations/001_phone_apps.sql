CREATE TABLE IF NOT EXISTS rp_phone_profiles (
 id INT UNSIGNED NOT NULL AUTO_INCREMENT, owner VARCHAR(80) NOT NULL,
 handle VARCHAR(24) DEFAULT NULL, name VARCHAR(60) NOT NULL, bio VARCHAR(160) NOT NULL DEFAULT '',
 contacts LONGTEXT NOT NULL DEFAULT '[]', tasks LONGTEXT NOT NULL DEFAULT '[]', bookmarks LONGTEXT NOT NULL DEFAULT '[]',
 PRIMARY KEY(id), UNIQUE KEY phone_owner(owner), UNIQUE KEY phone_handle(handle),
 CHECK(JSON_VALID(contacts)), CHECK(JSON_VALID(tasks)), CHECK(JSON_VALID(bookmarks))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS rp_phone_messages (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, sender INT UNSIGNED NOT NULL, recipient INT UNSIGNED NOT NULL,
 nonce VARCHAR(80) NOT NULL, body VARCHAR(1000) NOT NULL, created INT UNSIGNED NOT NULL, seen BOOLEAN NOT NULL DEFAULT FALSE,
 PRIMARY KEY(id), UNIQUE KEY phone_message_nonce(sender,nonce), KEY phone_inbox(recipient,id), KEY phone_outbox(sender,id),
 FOREIGN KEY(sender) REFERENCES rp_phone_profiles(id), FOREIGN KEY(recipient) REFERENCES rp_phone_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS rp_phone_photos (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, owner INT UNSIGNED NOT NULL, nonce VARCHAR(80) NOT NULL,
 image MEDIUMTEXT NOT NULL, created INT UNSIGNED NOT NULL,
 PRIMARY KEY(id), UNIQUE KEY phone_photo_nonce(owner,nonce), KEY phone_photos_owner(owner,id),
 FOREIGN KEY(owner) REFERENCES rp_phone_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS rp_phone_posts (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, author INT UNSIGNED NOT NULL, photo BIGINT UNSIGNED NOT NULL,
 nonce VARCHAR(80) NOT NULL, caption VARCHAR(1000) NOT NULL, created INT UNSIGNED NOT NULL,
 PRIMARY KEY(id), UNIQUE KEY phone_post_nonce(author,nonce), KEY phone_posts_author(author,id),
 FOREIGN KEY(author) REFERENCES rp_phone_profiles(id), FOREIGN KEY(photo) REFERENCES rp_phone_photos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS rp_phone_likes (
 post BIGINT UNSIGNED NOT NULL, profile INT UNSIGNED NOT NULL, PRIMARY KEY(post,profile),
 FOREIGN KEY(post) REFERENCES rp_phone_posts(id) ON DELETE CASCADE,
 FOREIGN KEY(profile) REFERENCES rp_phone_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS rp_phone_comments (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, post BIGINT UNSIGNED NOT NULL, author INT UNSIGNED NOT NULL,
 nonce VARCHAR(80) NOT NULL, body VARCHAR(400) NOT NULL, created INT UNSIGNED NOT NULL,
 PRIMARY KEY(id), UNIQUE KEY phone_comment_nonce(author,nonce), KEY phone_comments_post(post,id),
 FOREIGN KEY(post) REFERENCES rp_phone_posts(id) ON DELETE CASCADE,
 FOREIGN KEY(author) REFERENCES rp_phone_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS rp_phone_follows (
 follower INT UNSIGNED NOT NULL, target INT UNSIGNED NOT NULL, PRIMARY KEY(follower,target), KEY phone_followers(target),
 FOREIGN KEY(follower) REFERENCES rp_phone_profiles(id), FOREIGN KEY(target) REFERENCES rp_phone_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE IF NOT EXISTS rp_phone_call_history (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT, profile INT UNSIGNED NOT NULL, peer VARCHAR(16) NOT NULL,
 direction ENUM('in','out') NOT NULL, video BOOLEAN NOT NULL, outcome VARCHAR(16) NOT NULL, created INT UNSIGNED NOT NULL,
 PRIMARY KEY(id), KEY phone_calls_profile(profile,id), FOREIGN KEY(profile) REFERENCES rp_phone_profiles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
