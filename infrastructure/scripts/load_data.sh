#!/bin/bash

set -e

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Function to display usage
usage() {
  echo "Usage: $0 -d <path-to-data>"
  exit 1
}

# Parse command-line arguments
while getopts ":d:k:" opt; do
  case $opt in
    d)
      DATA_PATH=$OPTARG
      ;;
    k)
      KEY_FILE_PATH=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

# Check if .status file exists
if [ ! -f $SCRIPT_DIR/.status ]; then
  echo ".status file not found!"
  exit 1
fi

source $SCRIPT_DIR/.status

# Check if mandatory arguments are provided
if [ -z "$DATA_PATH" ] || [ -z "$KEY_FILE_PATH" ] || [ -z "$STACK_NAME" ] || [ -z "$REGION" ]; then
  usage
fi

echo $DATA_PATH
echo $KEY_FILE_PATH
echo $STACK_NAME
echo $REGION  

# Get URL from our deployed stack
URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='URL'].OutputValue" \
  --output text)

scp -o "StrictHostKeyChecking=no" -i "$KEY_FILE_PATH" -r "$DATA_PATH" "ubuntu@$URL:/home/ubuntu/"