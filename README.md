# Smart Sensor Gateway

Dit project simuleert een afstandssensor en een lichtsensor, verzamelt hun metingen via MQTT, verwerkt en valideert ze met Node-RED, slaat ze op in InfluxDB en toont ze in een dashboard. Portainer houdt in de gaten of alles draait, en Watchtower zorgt dat de simulator zichzelf automatisch bijwerkt zodra er een nieuwe versie beschikbaar is. Alles draait in Docker-containers, opgestart met één Compose-bestand.

Gemaakt door Bram De Bevere, Vives.

## Architectuur

```
DATAFLOW

  Simulator --> Mosquitto --> Node-RED --> InfluxDB --> Dashboard
   (MQTT)        (broker)    (validatie)    (opslag)

  Node-RED houdt enkel geldige metingen over.
  Ongeldige metingen gaan naar een debug-log, niet naar de databank.


BEHEER

  Portainer    Toont het overzicht van alle containers.
  Watchtower   Controleert om de 5 minuten op een nieuwe simulator-versie.
               en herstart de container automatisch.


CI/CD

  git push --> GitHub Actions (lint + build) --> GHCR --> Watchtower pullt het vanzelf
```

De simulator (Node.js-script) doet zich voor als een controller met een afstandssensor en een lichtsensor. Elke seconde stuurt hij een meting naar de MQTT-broker (Mosquitto), op twee aparte topics: `sensor/distance` (afstand in cm) en `sensor/light` (lichtsterkte in lux). Bewust genereert hij in ongeveer 5% van de gevallen een onmogelijke waarde, zoals een negatieve afstand, zodat er ook echt iets te valideren valt.

Node-RED luistert op beide topics en checkt elke meting in een zelfgeschreven function node: afstand moet tussen 0 en 400 cm liggen, licht tussen 0 en 1000 lux. Alles wat binnen dat bereik valt, wordt weggeschreven naar InfluxDB via de HTTP write-API. Alles wat erbuiten valt, verdwijnt niet zomaar, maar wordt gelogd in een debug-node zodat je kan zien dat de filtering effectief werkt.

In InfluxDB bouw je een dashboard met live grafieken en gemiddelden over 1 uur en 24 uur, zowel voor afstand als licht.

Portainer geeft een overzicht van alle containers en hun status. Watchtower checkt om de 5 minuten of er een nieuwere versie van het simulator-image op GitHub Container Registry staat, en herstart de container automatisch als dat zo is. Dat sluit meteen de CI/CD-keten: code pushen naar GitHub triggert een pipeline die het image bouwt en publiceert, en Watchtower merkt dat vanzelf op zonder dat iemand nog manueel iets moet herstarten.

Alle containers zitten samen op één eigen Docker-netwerk (`gateway-net`), waardoor ze elkaar gewoon bij naam kunnen vinden (bijvoorbeeld `mosquitto:1883`) in plaats van via IP-adressen.

## Installatie

**Vereisten**
- Een Linux-VM (getest met Debian 13 "Trixie" in VirtualBox), met NAT-poortdoorschakeling voor 1880, 8086 en 9000 (of een Bridged Adapter als je netwerk dat toelaat).
- Docker Engine met de Compose-plugin. Installeren kan met `curl -fsSL https://get.docker.com | sh`.
- Git.

**Stappen**

```bash
git clone https://github.com/BramDeBevere/sensor-gateway.git
cd sensor-gateway
cp .env.example .env
docker compose up -d          # gebruikt het kant-en-klare image van GHCR
# of
docker compose up -d --build  # bouwt het simulator-image lokaal vanuit de broncode
```

`.env.example` bevat al werkende standaardwaarden, dus je kan meteen starten. Wil je eigen wachtwoorden of een eigen token, pas ze dan gewoon aan in `.env` voor je opstart.

Check daarna of alles draait:

```bash
docker compose ps
```

Er zouden 6 services moeten staan: `mosquitto`, `sensor-simulator`, `node-red`, `influxdb`, `portainer` en `watchtower`, allemaal met status `Up`.

**Waar je terechtkan**

| Service | URL | Login |
|---|---|---|
| Node-RED editor | `http://localhost:1880` | geen |
| InfluxDB UI | `http://localhost:8086` | zie `.env` |
| Portainer | `http://localhost:9000` | eerste keer zelf een admin-account aanmaken |

## Dashboard bouwen in InfluxDB

Log in op `http://localhost:8086`, ga naar **Dashboards → New Dashboard**, en voeg per cel een query toe via de Script Editor.

Live afstand:
```flux
from(bucket: "sensors")
  |> range(start: -5m)
  |> filter(fn: (r) => r._measurement == "distance")
```

Live licht: hetzelfde, met `r._measurement == "light"`.

Gemiddelde afstand over 1 uur (celtype Single Stat):
```flux
from(bucket: "sensors")
  |> range(start: -1h)
  |> filter(fn: (r) => r._measurement == "distance")
  |> mean()
```

Voor 24 uur verander je `-1h` naar `-24h`. Voor licht verander je enkel de measurement-naam.

## CI/CD

Bij elke push naar `main` (met wijzigingen in `simulator/`) draait `.github/workflows/ci.yml` twee jobs na elkaar.

Eerst `lint-js`: installeert de dependencies en runt ESLint op de simulator-code. Faalt die stap, dan stopt de pipeline daar en wordt er niets gebouwd.

Daarna `build-and-push`, maar enkel als de linter geslaagd is. Die bouwt het simulator-image en publiceert het naar `ghcr.io/bramdebevere/sensor-gateway-simulator:latest`.

Mosquitto, Node-RED, InfluxDB en Portainer zijn kant-en-klare, officiële images. Die bouwen we niet zelf, we configureren ze enkel via environment-variabelen en volumes. Enkel de simulator is eigen code, dus enkel die wordt gebouwd en gepubliceerd.

**Lokaal: deploy.sh**

```bash
./deploy.sh          # pullt de nieuwste images, incl. simulator van GHCR
./deploy.sh --build   # bouwt de simulator lokaal in plaats van te pullen
```

Het script bouwt of pullt, stopt de draaiende containers, en start de stack opnieuw op. In een echte pipeline zou je dit niet manueel draaien, maar bijvoorbeeld een self-hosted GitHub Actions runner op de VM laten draaien die dit automatisch doet na elke geslaagde build. Watchtower (zie verder) is een lichter alternatief zonder eigen runner.

## Monitoring met Portainer

`http://localhost:9000` toont alle containers, hun status en logs in één overzicht, zodat je niet voor elke check apart de command line moet gebruiken.

## Bonusonderdelen

**Watchtower** monitort elke 5 minuten of er een nieuwere versie van het simulator-image op GHCR staat, en herstart de container automatisch als dat zo is. Dankzij een label op de simulator-service (`com.centurylinklabs.watchtower.enable=true`) kijkt Watchtower enkel naar die ene container, niet naar de rest van de stack. Gebruik hierbij het image `nickfedor/watchtower`: het originele `containrrr/watchtower` is sinds eind 2025 niet meer onderhouden en werkt niet meer met recente Docker-versies.

**backup.sh** maakt een tijdgestempelde back-up van alle InfluxDB-data via het ingebouwde `influx backup`-commando, en kopieert die van in de container naar de VM zelf. Zo overleeft de back-up ook een `docker compose down -v`.

## Projectstructuur

```
.
├── docker-compose.yml
├── .env.example
├── .gitignore
├── deploy.sh
├── backup.sh
├── mosquitto/config/mosquitto.conf
├── simulator/              Dockerfile + Node.js MQTT-publisher, eigen image op GHCR
├── node-red/data/          flows.json wordt automatisch geladen bij opstarten
├── .github/workflows/ci.yml
├── screenshots/
└── REFLECTIE.md
```
