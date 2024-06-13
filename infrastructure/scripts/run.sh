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
while getopts ":d:" opt; do
  case $opt in
    d)
      DATA_PATH=$OPTARG
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

# Run make first in case there's un-compiled changes
$MAKE_PATH

shift $((OPTIND -1))

docker pull ajferrario/autorag:latest
docker run --rm -it -v $DATA_PATH:/data --network host --name autorag ajferrario/autorag:latest "$@"