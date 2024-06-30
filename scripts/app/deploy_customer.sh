#!/bin/bash

set -e

# Directory paths
SCRIPT_DIR=$(dirname $(realpath "$0"))
STATE_DIR="$(dirname $(dirname $SCRIPT_DIR))/state"
ROOT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)

# Function to display usage
usage() {
  echo "Usage: $0 -n <deployment-name> -c <customer-env-file-path>"
  exit 1
}

# Parse command-line arguments
echo "Arguments:"
while getopts ":n:c:" opt; do
  echo "-$opt $OPTARG"
  case $opt in
    n)
      DEPLOYMENT_NAME="$OPTARG"
      ;;
    c)
      CUSTOMER_ENV_FILE_PATH="$OPTARG"
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
if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$CUSTOMER_ENV_FILE_PATH" ]; then
  usage
fi

# Check if .state file exists
echo "Collecting deployment .state file"
STATE_PATH="$STATE_DIR/$DEPLOYMENT_NAME/$DEPLOYMENT_NAME.state"
if [ ! -f "$STATE_PATH" ]; then
  echo "$DEPLOYMENT_NAME.state not found!"
  usage
fi
source $STATE_PATH

# Check if mandatory state is provided
if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$REGION" ] || [ -z "$KEY_FILE_PATH" ]; then
  usage
fi

echo "Confirming customer has not been deployed"
CUSTOMER_ENV_FILE_NAME=$(basename "$CUSTOMER_ENV_FILE_PATH")
ENV_PATH="$STATE_DIR/$DEPLOYMENT_NAME/$CUSTOMER_ENV_FILE_NAME"
if [ -f "$ENV_PATH" ]; then
  echo "$CUSTOMER_ENV_FILE_NAME found! Customer has already deployed."
  usage
fi
source $CUSTOMER_ENV_FILE_PATH

# Check if mandatory env vars are provided
if [ -z "$CUSTOMER_ID" ] || [ -z "$FOLDER_ID" ]; then
  echo "$CUSTOMER_ENV_FILE_NAME must contain CUSTOMER_ID and FOLDER_ID."
  exit 1
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
"$ROOT_DIR/docker-compose-customer.yml" \
"$ROOT_DIR/docker-compose-customer-no-gpu.yml" \
"$SCRIPT_DIR/gpu_check.sh" \
"$CUSTOMER_ENV_FILE_PATH" \
"ubuntu@$URL:/home/ubuntu/distill"

echo "FILENAME: ""$CUSTOMER_ENV_FILE_NAME"
CUSTOMER_NAME=$(basename "$CUSTOMER_ENV_FILE_NAME" | cut -d. -f1)
echo "Using CUSTOMER_NAME: $CUSTOMER_NAME"

INITIAL_COMMANDS=$(cat <<EOF
cd distill
NO_GPU=\$(./gpu_check.sh)
docker compose -f "docker-compose-customer\$NO_GPU.yml" -p "$CUSTOMER_NAME" --env-file $CUSTOMER_ENV_FILE_NAME up data_loader -d
nohup docker compose -f "docker-compose-customer\$NO_GPU.yml" -p "$CUSTOMER_NAME" --env-file $CUSTOMER_ENV_FILE_NAME logs -f >> log/docker-compose-customer-$CUSTOMER_NAME.log
while docker ps | grep -q "data_loader"; do
    echo "Waiting for 'data_loader' to exit..."
    sleep 5
done
echo "data_loader has exited."
docker compose -f "docker-compose-customer\$NO_GPU.yml" -p "$CUSTOMER_NAME" --env-file $CUSTOMER_ENV_FILE_NAME up query_server -d
nohup  docker compose -f "docker-compose-customer\$NO_GPU.yml" -p "$CUSTOMER_NAME" --env-file $CUSTOMER_ENV_FILE_NAME logs -f >> log/docker-compose-customer-$CUSTOMER_NAME.log
EOF
)

# Execute the initial commands on the remote server via SSH
echo "Launching shared services on $DEPLOYMENT_NAME"
ssh -t -o "StrictHostKeyChecking=no" -i "$KEY_FILE_PATH" "ubuntu@$URL" <<EOF
$INITIAL_COMMANDS
EOF

# Write env file
echo "Writing env file at: $ENV_PATH"
cp "$CUSTOMER_ENV_FILE_PATH" "$ENV_PATH"
echo "Env file written to state directory"