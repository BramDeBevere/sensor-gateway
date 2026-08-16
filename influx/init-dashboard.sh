#!/bin/sh
# Wacht tot InfluxDB klaar is, en maakt dan (enkel indien nog niet aanwezig)
# het Sensor Gateway dashboard aan vanuit het meegeleverde template.

set -e

echo ">> Wachten tot InfluxDB klaar is..."
until influx ping --host http://influxdb:8086 > /dev/null 2>&1; do
    sleep 2
done
echo ">> InfluxDB is klaar."

if influx dashboards --org "$INFLUX_ORG" --token "$INFLUX_TOKEN" --host http://influxdb:8086 --json 2>/dev/null | grep -q "Sensor Gateway"; then
    echo ">> Dashboard 'Sensor Gateway' bestaat al, niets te doen."
else
    echo ">> Dashboard aanmaken vanuit template..."
    influx apply -f /template.yml --org "$INFLUX_ORG" --token "$INFLUX_TOKEN" --host http://influxdb:8086 --force yes
    echo ">> Klaar."
fi
