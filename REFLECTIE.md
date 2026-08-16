# Reflectie

## Groepslid

Bram De Bevere — alle onderdelen van dit project (MQTT-simulator, Node-RED
flow, InfluxDB-opslag en dashboard, Docker Compose-stack, CI/CD-pipeline,
documentatie) zelfstandig opgezet.

## Wat liep goed?

- De basisarchitectuur (MQTT → Node-RED → InfluxDB) werkte al vrij snel
  end-to-end, nadat de validatielogica in Node-RED correct de auto-detecte
  JSON-payload leerde herkennen.
- Het testen met bewust foutieve sensordata (5% ongeldige waarden) maakte
  het makkelijk om aan te tonen dat de validatie ook echt werkt.
- Het gebruik van GHCR + GitHub Actions om het simulator-image automatisch
  te bouwen en te publiceren werkte uiteindelijk vlot, met "compose up" en
  "compose up --build" allebei getest en werkend.

## Wat was moeilijk?

- Eerste keer met VirtualBox-netwerkconfiguratie: Bridged Adapter werkte niet
  op een mobiele hotspot (client isolation), overgeschakeld naar NAT met
  poort-doorschakeling.
- Git: een bestand aanpassen zonder opnieuw `git add` te doen zorgde er 2 keer
  voor dat wijzigingen niet meekwamen in de commit (de CI/CD-workflow miste
  hierdoor initieel de build-and-push-job).
- GitHub personal access tokens hebben aparte scopes nodig per soort actie
  (`repo`, `workflow`, `packages`) — dat kostte een paar mislukte pushes om
  te ontdekken.
- GHCR accepteert geen hoofdletters in image-namen, terwijl een GitHub-
  gebruikersnaam die wel kan bevatten — opgelost met een extra
  workflow-stap die de naam expliciet naar kleine letters omzet.
- Eerste keer met een linter (ESLint): vergeten dat een configuratiebestand
  nodig is, waardoor de eerste CI-run faalde met "couldn't find a
  configuration file".

## Wat zou ik de volgende keer anders doen?

- Sneller de ingebouwde validatietools gebruiken (`docker compose config`,
  `git status` na elke wijziging) in plaats van pas achteraf te ontdekken
  dat een bestand niet correct gestaged of opgeslagen was.
- Van bij het begin een `.gitignore` en `.env.example` aanmaken, in plaats
  van dat pas te doen vlak voor de eerste push.
