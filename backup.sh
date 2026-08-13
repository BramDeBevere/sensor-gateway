#!/usr/bin/env bash
# Maakt een backup van alle InfluxDB-data (metingen + configuratie) naar
# een lokale, tijdgestempelde map. Kan manueel gedraaid worden, of via een
# cronjob voor automatische, periodieke backups.

set -euo pipefail

# .env inladen zodat we bij INFLUX_TOKEN kunnen
set -a
source .env
set +a

TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="./backups/$TIMESTAMP"
mkdir -p "$BACKUP_DIR"

echo ">> Backup maken van InfluxDB..."
docker exec influxdb influx backup /tmp/backup --token "$INFLUX_TOKEN"

echo ">> Backup uit de container kopiëren..."
docker cp influxdb:/tmp/backup "$BACKUP_DIR"
docker exec influxdb rm -rf /tmp/backup

echo ">> Klaar. Backup opgeslagen in: $BACKUP_DIR"
ls -la "$BACKUP_DIR"
