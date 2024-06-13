#!/bin/bash

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Function to display usage
usage() {
  echo "Usage: $0 requires a deployed stack."
  exit 1
}

# Check if .status file exists
if [ ! -f $SCRIPT_DIR/.status ]; then
  echo ".status file not found!"
  exit 1
fi

source $SCRIPT_DIR/.status

# Check if mandatory arguments are provided
if [ -z "$STACK_NAME" ] || [ -z "$REGION" ]; then
  echo $STACK_NAME
  echo $REGION  
  usage
fi

# Get the instance ID from the stack resource
INSTANCE_ID=$(aws cloudformation describe-stack-resources \
  --stack-name "$STACK_NAME" \
  --logical-resource-id "WebServerInstance" \
  --query "StackResources[0].PhysicalResourceId" \
  --output text)

# Check if the instance ID was found
if [ -z "$INSTANCE_ID" ]; then
  echo "Instance ID for resource '$RESOURCE_LOGICAL_ID' in stack '$STACK_NAME' not found."
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Stop the EC2 instance
aws ec2 start-instances --instance-ids "$INSTANCE_ID"

# Wait for the instance to stop
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

echo "Instance $INSTANCE_ID is running."