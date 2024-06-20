#!/bin/bash

set -e

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

usage() {
  echo "Usage: $0 [-d <data_directory> -l]"
  exit 1
}

# Default data directory
DATA_PATH="$(dirname $(dirname $SCRIPT_DIR))/data"
MAKE_PATH="$(dirname $(dirname $SCRIPT_DIR))/make.sh"

# Parse command-line arguments
while [[ "$1" =~ ^- && ! "$1" == "--" ]]; do
  case $1 in
    -d)
      shift
      DATA_PATH=$1
      ;;
    *)
      break
      ;;
  esac
  shift
done

source $SCRIPT_DIR/.status

URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='URL'].OutputValue" \
  --output text)

echo Passing through arguments "$@"
INITIAL_COMMANDS="docker pull ajferrario/autorag:latest; docker run --gpus all --rm -it -v /home/ubuntu/data:/data -v /home/ubuntu/log:/home/appuser/log --network host --name autorag ajferrario/autorag:latest "$@""
if [ -z "$LOCAL" ]; then
  ssh -t -o "StrictHostKeyChecking=no" -i $KEY_FILE_PATH "ubuntu@$URL" "${INITIAL_COMMANDS}; bash"
else
  docker pull ajferrario/autorag:latest
  docker run --rm -it -v $DATA_PATH:/data -v $(pwd):/home/appuser/log --network host --name autorag ajferrario/autorag:latest "$@"
fi