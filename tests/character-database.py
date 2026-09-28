"""Real MariaDB join regression. Uses only connection-local temporary tables.

Run from the root with the project's Docker database running:
    python tests/character-database.py
"""
from pathlib import Path
import re
import subprocess

source = Path('server-data/resources/[custom]/rp_characters/server/main.lua').read_text(encoding='utf-8')
queries = re.findall(r'MySQL\.(?:query|single)\.await\(\[\[(.*?)\]\]', source, re.S)
roster = next(query for query in queries if 'SELECT c.slot,' in query)
login = next(query for query in queries if 'SELECT c.esx_identifier,' in query)
roster = roster.replace('?', "'rp_test_account'", 1)
login = login.replace('?', "'rp_test_account'", 1).replace('?', '1', 1)
sql = r"""
CREATE TEMPORARY TABLE users (
    identifier VARCHAR(60) PRIMARY KEY,
    firstname VARCHAR(16), lastname VARCHAR(16), dateofbirth VARCHAR(10),
    sex VARCHAR(1), height INT, skin LONGTEXT, position LONGTEXT, job VARCHAR(20)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;
CREATE TEMPORARY TABLE jobs (
    name VARCHAR(50) PRIMARY KEY, label VARCHAR(50)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;
CREATE TEMPORARY TABLE rp_character_slots (
    account_identifier VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin,
    slot INT, esx_identifier VARCHAR(60), last_position LONGTEXT,
    PRIMARY KEY(account_identifier,slot), UNIQUE(esx_identifier)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO jobs VALUES ('unemployed','Test job');
"""
# Both queries must also work for a new account without any characters.
sql += roster + ';\n' + login + ';\n'
sql += r"""
SELECT 'EMPTY_QUERIES_OK';
INSERT INTO users VALUES ('char1:rp_test_account','Probe','Character','2000-01-01','m',180,'{"sex":0}','{"x":1}','unemployed');
INSERT INTO rp_character_slots VALUES ('rp_test_account',1,'char1:rp_test_account','{"x":2}');
"""
sql += roster + ';\n' + login + ';\n'
sql += "SELECT 'OWNED_QUERIES_OK';\n"
result = subprocess.run(
    ['docker', 'compose', 'exec', '-T', 'db', 'sh', '-c',
     'MYSQL_PWD=$MARIADB_PASSWORD mariadb --batch --skip-column-names -u$MARIADB_USER $MARIADB_DATABASE'],
    input=sql, text=True, capture_output=True, encoding='utf-8',
)
assert result.returncode == 0, result.stderr
lines = result.stdout.strip().splitlines()
assert len(lines) == 4 and lines[0] == 'EMPTY_QUERIES_OK' and lines[-1] == 'OWNED_QUERIES_OK', lines
assert lines[1].startswith('1\tProbe\tCharacter\t') and lines[2].startswith('char1:rp_test_account\t'), lines
print('PASS: actual roster and login SQL, empty/new and owned accounts, mixed ESX/custom collations; production tables unchanged')
