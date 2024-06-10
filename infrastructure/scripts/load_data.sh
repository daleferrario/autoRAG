#!/bin/bash

# Function to display usage
usage() {
  echo "Usage: $0 -d <path-to-data> -k <path-to-key>"
  exit 1
}

# Parse command-line arguments
while getopts ":d:k:" opt; do
  case $opt in
    d)
      DATA_PATH=$OPTARG
      ;;
    k)
      KEY_PATH=$OPTARG
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
if [ ! -f .status ]; then
  echo ".status file not found!"
  exit 1
fi

source .status

# Check if mandatory arguments are provided
if [ -z "$DATA_PATH" ] || [ -z "$KEY_PATH" ] || [ -z "$STACK_NAME" ] || [ -z "$REGION" ]; then
  echo $DATA_PATH
  echo $KEY_PATH
  echo $STACK_NAME
  echo $REGION  
  usage
fi

# Get URL from our deployed stack
URL=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='URL'].OutputValue" \
  --output text)

scp -o -i "$KEY_PATH" -r "$DATA_PATH" "ubuntu@$URL:/home/ubuntu/"