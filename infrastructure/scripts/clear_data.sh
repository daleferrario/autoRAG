#!/bin/bash

set -e

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
source $SCRIPT_DIR/.status

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

INITIAL_COMMANDS="docker stop chromadb; docker start chromadb"
ssh -t -o "StrictHostKeyChecking=no" -i $KEY_FILE_PATH "ubuntu@$URL" "${INITIAL_COMMANDS}"