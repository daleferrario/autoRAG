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

INSTANCE_ID=$(aws cloudformation describe-stack-resource \
  --stack-name "$STACK_NAME" \
  --logical-resource-id WebServerInstance \
  --region "$REGION" \
  --query "StackResourceDetail.PhysicalResourceId" \
  --output text)
  
if [ -z "$INSTANCE_ID" ]; then
  echo "Failed to get instance ID for WebServerInstance in stack $STACK_NAME."
  exit 1
fi

# Get the public DNS of the instance
URL=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicDnsName" \
  --output text)

echo $URL
echo "$KEY_FILE_PATH"
scp -o "StrictHostKeyChecking=no" -i "$KEY_FILE_PATH" -r "$DATA_PATH" "ubuntu@$URL:/home/ubuntu/"