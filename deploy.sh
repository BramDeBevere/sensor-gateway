#!/usr/bin/env bash
# CI/CD-achtig deploy-script: haalt de nieuwste images op (of bouwt lokaal),
# stopt de oude containers, en herstart de volledige stack.
#
# Gebruik:
#   ./deploy.sh          -> pullt de nieuwste images (o.a. simulator van GHCR)
#   ./deploy.sh --build  -> bouwt de simulator lokaal i.p.v. te pullen

set -euo pipefail

MODE="${1:-pull}"

echo ">> Stack bijwerken (modus: $MODE)..."

if [[ "$MODE" == "--build" ]]; then
    echo ">> Simulator-image lokaal bouwen..."
    docker compose build
else
    echo ">> Nieuwste images ophalen van registries..."
    docker compose pull
fi

echo ">> Oude containers stoppen..."
docker compose down

echo ">> Stack opnieuw opstarten..."
docker compose up -d

echo ">> Klaar. Status van de services:"
docker compose ps
