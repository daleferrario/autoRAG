#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname $(realpath "$0"))
ROOT_DIR=$(dirname "$SCRIPT_DIR")

docker compose -f $ROOT_DIR/docker-compose-build.yml pull
docker compose -f $ROOT_DIR/docker-compose-build.yml build --parallel
docker compose -f $ROOT_DIR/docker-compose-build.yml push