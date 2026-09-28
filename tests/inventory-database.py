"""Real MariaDB atomicity/CAS/replay/concurrency tests in uniquely named test tables.

Uses the project's Docker DB credentials without exposing them. Production inventory
tables are never changed. The test owns and removes only rp_invtest_<uuid> objects.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import uuid

prefix = 'rp_invtest_' + uuid.uuid4().hex[:12]
assert prefix.startswith('rp_invtest_') and prefix.replace('_', '').isalnum()
stores, operations, procedure = prefix + '_stores', prefix + '_operations', prefix + '_commit'
command = ['docker', 'compose', 'exec', '-T', 'db', 'sh', '-c',
           'MYSQL_PWD=$MARIADB_PASSWORD mariadb --batch --skip-column-names -u$MARIADB_USER $MARIADB_DATABASE']
def sql(value, success=True):
    result = subprocess.run(command, input=value, text=True, capture_output=True, encoding='utf-8')
    if success:
        assert result.returncode == 0, result.stderr
    else:
        assert result.returncode != 0, 'Expected SQL failure'
    return result.stdout.strip()

def call(request, fingerprint, a_rev, a_count, b_rev=None, b_count=None):
    second = f"'player:char2:test',{b_rev},'{{\"count\":{b_count}}}'" if b_rev is not None else 'NULL,NULL,NULL'
    return f"CALL {procedure}('char1:test','{request}','{fingerprint}','player:char1:test',{a_rev},'{{\"count\":{a_count}}}',{second});"

def state():
    return sql(f"SELECT id, revision, JSON_VALUE(payload, '$.count') FROM {stores} ORDER BY id;")

try:
    migration = Path('server-data/resources/[custom]/rp_inventory/migrations/001_inventory.sql').read_text(encoding='utf-8')
    migration = migration.replace('rp_inventory_stores', stores).replace('rp_inventory_operations', operations).replace('rp_inventory_commit', procedure)
    sql(migration)
    sql(f"INSERT INTO {stores}(id,kind,label,payload,context) VALUES ('player:char1:test','player','A','{{\"count\":10}}','{{}}'),('player:char2:test','player','B','{{\"count\":0}}','{{}}');")
    assert sql(call('transfer-1', 'fingerprint1', 0, 6, 0, 4)) == 'committed'
    assert state() == 'player:char1:test\t1\t6\nplayer:char2:test\t1\t4'
    assert sql(call('transfer-1', 'fingerprint1', 0, 6, 0, 4)) == 'replayed'
    sql(call('transfer-1', 'different', 1, 0, 1, 10), False)
    sql(call('stale-second', 'stale', 1, 0, 0, 10), False)
    assert state() == 'player:char1:test\t1\t6\nplayer:char2:test\t1\t4', 'second-row conflict must roll back the first row'
    assert sql(f"SELECT COUNT(*) FROM {operations};") == '1'
    with ThreadPoolExecutor(max_workers=6) as pool:
        futures = [pool.submit(subprocess.run, command, input=call(f'concurrent-{i}', 'concurrent', 1, 5, 1, 5),
                              text=True, capture_output=True, encoding='utf-8') for i in range(6)]
        results = [f.result() for f in futures]
    assert sum(r.returncode == 0 for r in results) == 1, [r.stderr for r in results]
    assert state() == 'player:char1:test\t2\t5\nplayer:char2:test\t2\t5'
    assert sql(f"SELECT COUNT(*) FROM {operations};") == '2'
    # A successful commit with no caller acknowledgement remains idempotent on reconnect.
    sql(call('lost-reply', 'reply', 2, 3, 2, 7))
    assert sql(call('lost-reply', 'reply', 2, 3, 2, 7)) == 'replayed'
    assert state() == 'player:char1:test\t3\t3\nplayer:char2:test\t3\t7'
    sql(f"CALL {procedure}('x','reversed','order','player:char2:test',3,'{{}}','player:char1:test',3,'{{}}');", False)
    assert sql(f"SELECT SUM(JSON_VALUE(payload, '$.count')) FROM {stores};") == '10'
    print('PASS: real MariaDB commit, replay, fingerprint mismatch, second-row rollback, six concurrent writers, lost reply, character isolation and lock order')
finally:
    sql(f'DROP PROCEDURE IF EXISTS {procedure}; DROP TABLE IF EXISTS {operations}; DROP TABLE IF EXISTS {stores};')
