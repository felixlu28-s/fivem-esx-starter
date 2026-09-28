"""Real MariaDB order journal checks in a uniquely named disposable table."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import uuid

table = 'rp_commercetest_' + uuid.uuid4().hex[:12]
shops_table = table + '_shops'
assert table.startswith('rp_commercetest_') and table.replace('_', '').isalnum()
command = ['docker', 'compose', 'exec', '-T', 'db', 'sh', '-c',
           'MYSQL_PWD=$MARIADB_PASSWORD mariadb --batch --skip-column-names -u$MARIADB_USER $MARIADB_DATABASE']
def sql(statement, success=True):
    result = subprocess.run(command, input=statement, text=True, capture_output=True, encoding='utf-8')
    assert (result.returncode == 0) == success, result.stderr
    return result.stdout.strip()

try:
    sql(Path('server-data/resources/[custom]/rp_commerce/migrations/001_orders.sql').read_text(encoding='utf-8').replace('rp_commerce_orders', table))
    insert = f"INSERT INTO {table}(actor,request_id,fingerprint,payload,status) VALUES ('char1:test','request-test','shop|water|money|2|24','{{\"total\":24}}','intent');"
    with ThreadPoolExecutor(max_workers=5) as pool:
        results = list(pool.map(lambda _: subprocess.run(command, input=insert, text=True, capture_output=True), range(5)))
    assert sum(r.returncode == 0 for r in results) == 1, 'same order must have one durable intent'
    sql(insert.replace('char1:test', 'char2:test'))
    assert sql(f'SELECT COUNT(*) FROM {table};') == '2', 'character orders are isolated'
    sql(f"UPDATE {table} SET status='paid',review_note='Verified ESX debit' WHERE actor='char1:test' AND request_id='request-test' AND status='intent';")
    assert sql(f"SELECT status FROM {table} WHERE actor='char2:test';") == 'intent'
    sql(f"UPDATE {table} SET status='completed' WHERE actor='char1:test' AND request_id='request-test';")
    assert sql(f"SELECT COUNT(*) FROM {table} WHERE actor='char1:test' AND status IN ('intent','paid');") == '0'
    assert sql(f"SELECT COUNT(*) FROM {table} WHERE actor='char2:test' AND status IN ('intent','paid');") == '1'
    sql(f"INSERT INTO {table}(actor,request_id,fingerprint,payload,status) VALUES ('char1:test','bad-json','x','broken','intent');", False)
    print('PASS: real MariaDB order uniqueness with five writers, character isolation, durable status transitions, audit note and JSON constraint')
    sql(Path('server-data/resources/[custom]/rp_commerce/migrations/003_shops.sql').read_text(encoding='utf-8').replace('rp_commerce_shops', shops_table))
    seed = f"INSERT IGNORE INTO {shops_table}(id,payload,updated_by) VALUES ('original_venue','{{}}','config:test');"
    sql(seed)
    update = f"UPDATE {shops_table} SET payload='{{\"label\":\"edited\"}}',revision=revision+1 WHERE id='original_venue' AND revision=1 AND deleted=0; SELECT ROW_COUNT();"
    with ThreadPoolExecutor(max_workers=5) as pool:
        saved = list(pool.map(lambda _: sql(update), range(5)))
    assert saved.count('1') == 1 and saved.count('0') == 4, saved
    sql(f"UPDATE {shops_table} SET deleted=1,revision=revision+1 WHERE id='original_venue' AND revision=2;")
    sql(seed)
    assert sql(f"SELECT CONCAT(deleted,':',revision) FROM {shops_table} WHERE id='original_venue';") == '1:3'
    sql(f"INSERT INTO {shops_table}(id,payload,updated_by) VALUES ('bad','broken','test');", False)
    print('PASS: real MariaDB shop CAS with five concurrent editors; reimport preserves deletion tombstone; JSON constraint')
finally:
    sql(f'DROP TABLE IF EXISTS {shops_table};')
    sql(f'DROP TABLE IF EXISTS {table};')
