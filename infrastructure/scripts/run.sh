#!/bin/bash

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

usage() {
  echo "Usage: $0 [-d <data_directory>]"
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

# Run make first in case there's un-compiled changes
$MAKE_PATH

echo Passing through arguments "$@"
docker pull ajferrario/autorag:latest
docker run --rm -it -v $DATA_PATH:/data -v $(pwd):/home/appuser/log --network host --name autorag ajferrario/autorag:latest "$@"