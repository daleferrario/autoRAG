#!/bin/bash

set -e

# Directory paths
SCRIPT_DIR=$(dirname $(realpath "$0"))
STATE_DIR="$(dirname $(dirname $SCRIPT_DIR))/state"
ROOT_DIR=$(dirname $(dirname $SCRIPT_DIR))

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

# Check if mandatory arguments are provided
if [ -z "$DEPLOYMENT_NAME" ]; then
  usage
fi

# Check if .state file exists
echo "Collecting .state file"
STATE_PATH="$STATE_DIR/$DEPLOYMENT_NAME/$DEPLOYMENT_NAME.state"
if [ ! -f "$STATE_PATH" ]; then
  echo "$DEPLOYMENT_NAME.state not found!"
  usage
  exit 1
fi
source $STATE_PATH

# Check if mandatory arguments are provided
if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$REGION" ] || [ -z "$KEY_FILE_PATH" ]; then
  usage
fi

# Get the instance ID from the stack resource
INSTANCE_ID=$(aws cloudformation describe-stack-resources \
  --stack-name "$DEPLOYMENT_NAME" \
  --logical-resource-id "WebServerInstance" \
  --query "StackResources[0].PhysicalResourceId" \
  --output text \
  --region "$REGION")

# Check if the instance ID was found
if [ -z "$INSTANCE_ID" ]; then
  echo "Instance ID for resource '$RESOURCE_LOGICAL_ID' in stack '$DEPLOYMENT_NAME' not found."
  exit 1
fi

echo "Instance ID: $INSTANCE_ID"

# Get the public DNS of the instance
URL=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicDnsName" \
  --output text)

echo "URL of instance: $URL"

# Copying files
echo "Copying docker compose files to instance."
scp -o "StrictHostKeyChecking=no" -i "$KEY_FILE_PATH" \
"$ROOT_DIR/docker-compose-shared.yml" \
"$ROOT_DIR/docker-compose-shared-no-gpu.yml" \
"$SCRIPT_DIR/gpu_check.sh" \
"ubuntu@$URL:/home/ubuntu/"

INITIAL_COMMANDS=$(cat <<EOF
source ./gpu_check.sh
docker compose -f "docker-compose-shared\$NO_GPU.yml" up -d
EOF
)

# Execute the initial commands on the remote server via SSH
echo "Launching shared services on $DEPLOYMENT_NAME"
ssh -t -o "StrictHostKeyChecking=no" -i "$KEY_FILE_PATH" "ubuntu@$URL" <<EOF
$INITIAL_COMMANDS
EOF