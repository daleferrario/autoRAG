#!/bin/bash

set -e

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

usage() {
  echo "Usage: $0"
  exit 1
}

# Default data directory
DATA_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/data"
MAKE_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/make.sh"

# Source the .status file for environment variables
source "$SCRIPT_DIR/.status"

# Get the URL from the AWS CloudFormation stack outputs
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

echo "$URL"
echo "Passing through arguments: $@"

INITIAL_COMMANDS="\
[ nvidia-smi -L &> /dev/null ] && GPU_OPTION=\"--gpus all\"
echo \"Running Docker pull and run commands\"; \
docker pull ajferrario/autorag:latest; \
docker run \$GPU_OPTION --rm -it \
  -v /home/ubuntu/data:/data \
  -v /home/ubuntu/log:/home/appuser/log \
  --network host \
  --name autorag \
  ajferrario/autorag:latest \"$@\" \
"
# Execute the initial commands on the remote server via SSH
ssh -t -o "StrictHostKeyChecking=no" -i "$KEY_FILE_PATH" "ubuntu@$URL" "${INITIAL_COMMANDS}; bash"

