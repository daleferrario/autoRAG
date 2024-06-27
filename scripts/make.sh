#!/bin/bash

# Get the directory of the script
SCRIPT_DIR=$(dirname $(realpath "$0"))

docker-compose -f $SCRIPT_DIR/docker-compose-build.yml build --parallel
docker-compose -f $SCRIPT_DIR/docker-compose-build.yml push