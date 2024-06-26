#!/bin/bash

set -e

# Directory paths
SCRIPT_DIR=$(dirname $(realpath "$0"))
STATE_DIR="$(dirname $(dirname $SCRIPT_DIR))/state"
TEMPLATE_DIR="$(dirname $(dirname $SCRIPT_DIR))/infrastructure/app"

# Function to display usage
usage() {
  echo "Usage: $0 -n <deployment-name> -k <path-to-key-file> [-i <ec2-instance-type> -r <aws-region-name>]"
  exit 1
}

# Parse command-line arguments
echo "Arguments:"
while getopts ":n:k:i:r:" opt; do
  echo "-$opt $OPTARG"
  case $opt in
    n)
      DEPLOYMENT_NAME="$OPTARG"
      ;;
    k)
      KEY_FILE_PATH="$OPTARG"
      ;;
    i)
      INSTANCE_TYPE="$OPTARG"
      ;;
    r)
      AWS_REGION_NAME="$OPTARG"
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

# Check if mandatory arguments are provided
if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$KEY_FILE_PATH" ]; then
  usage
fi

if [ -n "$AWS_REGION_NAME" ]; then
  REGION="$AWS_REGION_NAME"
else
  REGION=$(aws configure get region)
  echo "No region provided. Using configured default region: $REGION"
fi

KEY_PAIR=$(basename "$KEY_FILE_PATH" | cut -d. -f1)
echo "Inferred KEY_PAIR based on KEY_FILE_PATH: $KEY_PAIR"

# Create CloudFormation stack
echo "Creating Cloudformation stack"
TEMPLATE_PATH="$TEMPLATE_DIR/distill.yml"
aws cloudformation create-stack \
  --stack-name "$DEPLOYMENT_NAME" \
  --template-body "file://$TEMPLATE_PATH" \
  --parameters \
  ParameterKey=KeyPair,ParameterValue="$KEY_PAIR" \
  ParameterKey=InstanceType,ParameterValue="${INSTANCE_TYPE:-t3.small}" \
  --region "$REGION"

# Wait for the stack to be created
echo "Waiting for Cloudformation stack creation to complete"
aws cloudformation wait stack-create-complete --stack-name "$DEPLOYMENT_NAME" --region "$REGION"

# Output the stack status
aws cloudformation describe-stacks --stack-name "$DEPLOYMENT_NAME" --query "Stacks[0].StackStatus" --output text --region "$REGION"

echo "Collecting instance ID"
INSTANCE_ID=$(aws cloudformation describe-stack-resource \
  --stack-name "$DEPLOYMENT_NAME" \
  --logical-resource-id DevServer \
  --region "$REGION" \
  --query "StackResourceDetail.PhysicalResourceId" \
  --output text)

if [ -z "$INSTANCE_ID" ]; then
  echo "Failed to get instance ID for DevServer in stack $DEPLOYMENT_NAME."
  exit 1
fi
echo "Instance ID: $INSTANCE_ID"

# Function to check instance status
check_instance_status() {
    aws ec2 describe-instance-status \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'InstanceStatuses[0].InstanceStatus.Status' \
        --output text
}

# Function to check system status
check_system_status() {
    aws ec2 describe-instance-status \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --query 'InstanceStatuses[0].SystemStatus.Status' \
        --output text
}

# Wait until both instance and system status are 'ok'
echo Wait until both instance and system status are 'ok'
while true; do
    INSTANCE_STATUS=$(check_instance_status)
    SYSTEM_STATUS=$(check_system_status)

    echo "Instance status: $INSTANCE_STATUS"
    echo "System status: $SYSTEM_STATUS"

    if [ "$INSTANCE_STATUS" == "ok" ] && [ "$SYSTEM_STATUS" == "ok" ]; then
        echo "Instance $INSTANCE_ID has finished initializing."
        break
    else
        echo "Instance $INSTANCE_ID is still initializing. Waiting..."
        sleep 10
    fi
done

# Write state file
mkdir -p "$STATE_DIR/$DEPLOYMENT_NAME"
STATE_PATH="$STATE_DIR/$DEPLOYMENT_NAME/$DEPLOYMENT_NAME.state"
echo "Writing state file at: $STATE_PATH"
{
  echo "DEPLOYMENT_NAME=\"$DEPLOYMENT_NAME\""
  echo "REGION=\"$REGION\""
  echo "KEY_FILE_PATH=\"$KEY_FILE_PATH\""
} > "$STATE_PATH"
echo "Stack information written to state file"
