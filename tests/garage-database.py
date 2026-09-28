"""Real MariaDB migration/CAS checks on uniquely named scratch tables only."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import uuid

prefix = 'rp_test_garage_' + uuid.uuid4().hex[:10]
vehicles, operations = prefix + '_vehicles', prefix + '_operations'


def sql(text):
    result = subprocess.run(
        ['docker', 'compose', 'exec', '-T', 'db', 'sh', '-c',
         'MYSQL_PWD=$MARIADB_PASSWORD mariadb --batch --skip-column-names -u$MARIADB_USER $MARIADB_DATABASE'],
        input=text, text=True, capture_output=True, check=True)
    return result.stdout.strip()


migration = Path('server-data/resources/[custom]/rp_vehicles/migrations/001_garage_operations.sql').read_text(encoding='utf-8')
migration = migration.replace('owned_vehicles', vehicles).replace('rp_vehicle_garage_operations', operations)
try:
    sql(migration)
    sql(f"INSERT INTO {vehicles} (owner,plate,vehicle,type,stored,parking) VALUES "
        "('char1:license:test','TESTA','{\"model\":123,\"modEngine\":3}', 'car',1,'la_mesa'),"
        "('char2:license:test','TESTB','{\"model\":123}', 'car',1,'la_mesa');")
    sql(migration)
    assert sql(f'SELECT COUNT(*) FROM {vehicles};') == '2', 'idempotent migration preserves existing cars'
    statement = f"UPDATE {vehicles} SET stored=0 WHERE plate='TESTA' AND owner='char1:license:test' AND stored=1; SELECT ROW_COUNT();"
    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(sql, [statement, statement]))
    assert sorted(results) == ['0', '1'], 'only one competing reservation succeeds'
    assert sql(f"UPDATE {vehicles} SET stored=0 WHERE plate='TESTB' AND owner='char1:license:test' AND stored=1; SELECT ROW_COUNT();") == '0'
    assert sql(f"SELECT JSON_EXTRACT(vehicle,'$.modEngine') FROM {vehicles} WHERE plate='TESTA';") == '3'
    sql(f"INSERT INTO {operations} (token,owner,plate,garage,direction,phase) VALUES ('op1','char1:license:test','TESTA','la_mesa','out','spawned');")
    assert sql(f"SELECT phase FROM {operations} WHERE token='op1';") == 'spawned'
    print('garage-database: migration, preservation, concurrent CAS, character isolation and journal passed')
finally:
    assert vehicles.startswith(prefix + '_') and operations.startswith(prefix + '_')
    sql(f'DROP TABLE IF EXISTS {operations}; DROP TABLE IF EXISTS {vehicles};')
