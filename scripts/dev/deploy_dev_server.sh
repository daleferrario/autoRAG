#!/bin/bash

set -e

# Directory paths
SCRIPT_DIR=$(dirname $(realpath "$0"))
STATE_DIR="$(dirname $(dirname $SCRIPT_DIR))/state"
TEMPLATE_DIR="$(dirname $(dirname $SCRIPT_DIR))/infrastructure/dev"

# Function to display usage
usage() {
  echo "Usage: $0 -k <path-to-key-file> [-i <ec2-instance-type>]"
  exit 1
}

# Parse command-line arguments
echo "Arguments:"
while getopts ":k:i:" opt; do
  echo "-$opt $OPTARG"
  case $opt in
    k)
      KEY_FILE_PATH="$OPTARG"
      ;;
    i)
      INSTANCE_TYPE="$OPTARG"
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
if [ -z "$KEY_FILE_PATH" ]; then
  usage
fi

# Setting Region
REGION="us-east-1"
echo "Using low-cost region: $REGION"

# Setting Deployment Name
DEPLOYMENT_NAME="dev-server"

KEY_PAIR=$(basename "$KEY_FILE_PATH" | cut -d. -f1)
echo "Inferred KEY_PAIR based on KEY_FILE_PATH: $KEY_PAIR"

# Create CloudFormation stack
echo "Creating Cloudformation stack"
TEMPLATE_PATH="$TEMPLATE_DIR/dev_server.yml"
aws cloudformation create-stack \
  --stack-name "$DEPLOYMENT_NAME" \
  --template-body "file://$TEMPLATE_PATH" \
  --parameters \
  ParameterKey=KeyPair,ParameterValue="$KEY_PAIR" \
  ParameterKey=InstanceType,ParameterValue="${INSTANCE_TYPE:-t3a.large}" \
  --region "$REGION"

# Wait for the stack to be created
echo "Waiting for Cloudformation stack creation to complete"
aws cloudformation wait stack-create-complete --stack-name "$DEPLOYMENT_NAME" --region "$REGION"

# Output the stack status
aws cloudformation describe-stacks --stack-name "$DEPLOYMENT_NAME" --query "Stacks[0].StackStatus" --output text --region "$REGION"

# Get the SSH call needed for the dev server
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
# Get the public DNS of the instance
echo "Getting public DNS for Instance."
URL=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicDnsName" \
  --output text)
echo "Public URL: $URL"

# Write state file
STATE_PATH="$STATE_DIR/$DEPLOYMENT_NAME.state"
echo "Writing state file at: $STATE_PATH"
{
  echo "DEPLOYMENT_NAME=\"$DEPLOYMENT_NAME\""
  echo "REGION=\"$REGION\""
  echo "KEY_FILE_PATH=\"$KEY_FILE_PATH\""
} > "$STATE_PATH"
echo "Stack information written to state file"
