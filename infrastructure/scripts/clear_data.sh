#!/bin/bash

set -e

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source $SCRIPT_DIR/.status

URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='URL'].OutputValue" \
  --output text)

INITIAL_COMMANDS="docker stop chromadb; docker pull chromadb/chroma; docker run --restart=always --rm -d -p 8000:8000 --name chromadb chromadb/chroma"
ssh -t -o "StrictHostKeyChecking=no" -i $KEY_FILE_PATH "ubuntu@$URL" "${INITIAL_COMMANDS}"