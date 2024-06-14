#!/bin/bash

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# server code
docker pull ajferrario/autorag:latest
docker build -t ajferrario/autorag:latest $SCRIPT_DIR/server/ 

if [ $? -ne 0 ]; then
  echo "Docker build failed."
  exit 1
fi

echo "Logging in to Docker..."
docker login

docker push ajferrario/autorag:latest