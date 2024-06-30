#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname $(realpath "$0"))
ROOT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)

docker compose -f $ROOT_DIR/docker-compose-build.yml pull
docker compose -f $ROOT_DIR/docker-compose-build.yml build --parallel
docker compose -f $ROOT_DIR/docker-compose-build.yml push