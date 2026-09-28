"""Installed ESX SavePlayer + actual project SQL against temporary MariaDB tables.

Requires local ESX 1.15.2, pip install lupa, and docker compose up -d db.
Never writes production tables. This complements, not replaces, a FiveM join test.
"""
from pathlib import Path
import re
import subprocess
from lupa.lua54 import LuaRuntime

source = Path('server-data/resources/[esx]/es_extended/server/functions.lua').read_text(encoding='utf-8')
start = source.index('local function updateHealthAndArmorInMetadata')
end = source.index('function Core.SavePlayers', start)
save_code = source[start:end]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute('''
Core = {}; writes = {}; json = { encode = function(value) return value end }
function GetPlayerPed(id) return id end
function GetEntityHealth() return 200 end
function GetPedArmour() return 0 end
function TriggerEvent() end
MySQL = { prepare = function(query, params, callback)
    writes[#writes + 1] = { query = query, params = params }; callback(1)
end }
''')
lua.execute(save_code)
lua.execute('''
local function character(prefix, job, bank, items, x)
    return { identifier = prefix .. ':rp_isolation_account', source = 12, spawned = true,
        name = prefix, job = { name = job, grade = 0 }, group = 'user',
        getAccounts = function() return '{"bank":' .. bank .. '}' end,
        getInventory = function() return items end,
        getCoords = function() return '{"x":' .. x .. ',"y":0,"z":20}' end,
        getLoadout = function() return '{}' end, getMeta = function() return '{}' end,
        setMeta = function() end, getPlayTime = function() return 0 end }
end
Core.SavePlayer(character('char1', 'police', 12345, '{"bread":2}', 100))
Core.SavePlayer(character('char2', 'mechanic', 987, '{"water":5}', 200))
Core.SavePlayer(character('char1', 'police', 12000, '{"bread":1}', 150))
''')

def literal(value):
    return str(value) if isinstance(value, (int, float)) else "'" + str(value).replace("'", "''") + "'"

def bind(query, params):
    parts = query.split('?')
    assert len(parts) == len(params) + 1
    return ''.join(part + (literal(params[i]) if i < len(params) else '') for i, part in enumerate(parts)) + ';\n'

sql = '''
CREATE TEMPORARY TABLE users (
 identifier VARCHAR(60) PRIMARY KEY, accounts LONGTEXT, job VARCHAR(50), job_grade INT,
 `group` VARCHAR(50), position LONGTEXT, inventory LONGTEXT, loadout LONGTEXT, metadata LONGTEXT,
 firstname VARCHAR(16), lastname VARCHAR(16), skin LONGTEXT
) CHARACTER SET utf8mb4 COLLATE utf8mb4_uca1400_ai_ci;
INSERT INTO users (identifier,firstname,lastname,skin) VALUES
 ('char1:rp_isolation_account','First','Character','{"sex":0}'),
 ('char2:rp_isolation_account','Second','Character','{"sex":1}');
CREATE TEMPORARY TABLE rp_factions (name VARCHAR(32) PRIMARY KEY, label VARCHAR(40))
 CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TEMPORARY TABLE rp_faction_members (
 faction VARCHAR(32), identifier VARCHAR(60) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
 grade INT, PRIMARY KEY(faction, identifier)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO rp_factions VALUES ('lost','Lost'),('riders','Riders');
'''
writes = lua.globals().writes
for i in range(1, len(writes) + 1):
    row = writes[i]
    params = [row.params[j] for j in range(1, len(row.params) + 1)]
    assert params[-1].startswith(('char1:', 'char2:'))
    sql += bind(row.query, params)
sql += '''
SELECT IF(job='police' AND JSON_VALUE(accounts,'$.bank')=12000
 AND JSON_VALUE(inventory,'$.bread')=1 AND JSON_VALUE(position,'$.x')=150
 AND JSON_VALUE(skin,'$.sex')=0, 'CHAR1_OK','FAIL') FROM users WHERE identifier='char1:rp_isolation_account';
SELECT IF(job='mechanic' AND JSON_VALUE(accounts,'$.bank')=987
 AND JSON_VALUE(inventory,'$.water')=5 AND JSON_VALUE(position,'$.x')=200
 AND JSON_VALUE(skin,'$.sex')=1, 'CHAR2_OK','FAIL') FROM users WHERE identifier='char2:rp_isolation_account';
'''
factions = Path('server-data/resources/[custom]/rp_organizations/server/factions.lua').read_text(encoding='utf-8')
queries = re.findall(r'MySQL\.(?:query|update)\.await\(\[\[(.*?)\]\]', factions, re.S)
hire = next(q for q in queries if 'INSERT INTO rp_faction_members' in q)
roster = next(q for q in queries if 'JOIN users u' in q)
sql += bind(hire, ['char1:rp_isolation_account', 2, 'lost', 'char1:rp_isolation_account', 1])
sql += bind(hire, ['char2:rp_isolation_account', 0, 'riders', 'char2:rp_isolation_account', 1])
# A second faction for char1 must be blocked by the configured per-character cap.
sql += bind(hire, ['char1:rp_isolation_account', 0, 'riders', 'char1:rp_isolation_account', 1])
sql += bind(roster, ['lost', 200]) + bind(roster, ['riders', 200])
sql += "SELECT IF(COUNT(*)=2,'FACTION_CAP_OK','FAIL') FROM rp_faction_members;\n"
result = subprocess.run(['docker','compose','exec','-T','db','sh','-c',
    'MYSQL_PWD=$MARIADB_PASSWORD mariadb --batch --skip-column-names -u$MARIADB_USER $MARIADB_DATABASE'],
    input=sql, text=True, capture_output=True, encoding='utf-8')
assert result.returncode == 0, result.stderr
rows = result.stdout.strip().splitlines()
assert rows == ['CHAR1_OK', 'CHAR2_OK', 'char1:rp_isolation_account\t2\tFirst\tCharacter',
                'char2:rp_isolation_account\t0\tSecond\tCharacter', 'FACTION_CAP_OK'], rows
print('PASS: installed ESX SavePlayer isolates jobs, accounts, inventories, position and skin; actual faction SQL isolates membership and caps across two characters on one account, mixed collations; production data unchanged')
