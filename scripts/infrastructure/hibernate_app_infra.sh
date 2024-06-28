#!/bin/bash

set -e

# Directory paths
SCRIPT_DIR=$(dirname $(realpath "$0"))
STATE_DIR="$(dirname $(dirname $SCRIPT_DIR))/state"

# Function to display usage
usage() {
  echo "Usage: $0 -n <deployment-name>"
  exit 1
}

# Parse command-line arguments
echo "Arguments:"
while getopts ":n:" opt; do
  echo "-$opt $OPTARG"
  case $opt in
    n)
      DEPLOYMENT_NAME="$OPTARG"
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

if [ -z "$DEPLOYMENT_NAME" ]; then
  usage
fi

# Check if .state file exists
echo "Collecting .state file"
STATE_PATH="$STATE_DIR/$DEPLOYMENT_NAME/$DEPLOYMENT_NAME.state"
if [ ! -f "$STATE_PATH" ]; then
  echo "$DEPLOYMENT_NAME.state not found!"
  exit 1
fi
source $STATE_PATH

# Check if mandatory arguments are provided
if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$REGION" ]; then
  usage
fi

# Get the instance ID from the stack resource
INSTANCE_ID=$(aws cloudformation describe-stack-resources \
  --stack-name "$DEPLOYMENT_NAME" \
  --logical-resource-id "DevServer" \
  --query "StackResources[0].PhysicalResourceId" \
  --output text \
  --region "$REGION")

# Check if the instance ID was found
if [ -z "$INSTANCE_ID" ]; then
  echo "Instance ID for resource '$RESOURCE_LOGICAL_ID' in stack '$DEPLOYMENT_NAME' not found."
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Stop the EC2 instance
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$REGION"

# Wait for the instance to stop
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" --region "$REGION"

echo "Instance $INSTANCE_ID has been stopped."