#!/bin/bash

set -e

# Directory paths
SCRIPT_DIR=$(dirname "$(realpath "$0")")
STATE_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")/state"

# Function to display usage
usage() {
  echo "Usage: $0 dev server must be deployed."
  exit 1
}

# Check if .state file exists
echo "Collecting .state file"
STATE_PATH="$STATE_DIR/dev-server-$(hostname)/dev-server-$(hostname).state"
if [ ! -f "$STATE_PATH" ]; then
  echo "dev-server-$(hostname).state not found!"
  usage
fi

source "$STATE_PATH"

# Check if mandatory arguments are provided
if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$REGION" ] || [ -z "$KEY_FILE_PATH" ]; then
  usage
fi

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

# Start instance if needed
echo "Starting Instance if needed"
aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$REGION"

# Wait for the instance to start
echo "Waiting for instance to be running"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"

# Get the public DNS of the instance
echo "Getting public DNS for Instance."
URL=$(aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$REGION" \
  --query "Reservations[0].Instances[0].PublicDnsName" \
  --output text)
echo "Public URL: $URL"

if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
    echo "Detected running in WSL. Configuring SSH in Windows layer"
    # Collect drive of Windows user profile
    win_userprofile="$(cmd.exe /c "<nul set /p=%UserProfile%" 2>/dev/null | tr -d '\r')"
    echo "Detected Windows User Profile: $win_userprofile"
    win_userprofile_drive="${win_userprofile%%:*}"
    win_userprofile_dir="${win_userprofile#*:}"
    userprofile_mount="/mnt/${win_userprofile_drive,,}"
    userprofile="${userprofile_mount}${win_userprofile_dir//\\//}"
    echo "User profile location in WSL filesystem: $userprofile"
    SSH_HOME=$userprofile
else
    SSH_HOME=$HOME
fi

# Set variables
USER="ubuntu"
SSH_CONFIG="$SSH_HOME/.ssh/config"
echo "SSH_CONFIG target file: $SSH_CONFIG"

# Create .ssh directory if it does not exist
mkdir -p "$SSH_HOME/.ssh"

# Create the config file if it does not exist
touch "$SSH_CONFIG"

# Backup existing config file
cp "$SSH_CONFIG" "$SSH_CONFIG.bak"

# Remove existing configuration for the alias if it exists
awk -v deployment_name="$DEPLOYMENT_NAME" '
  $1 == "Host" && $2 == deployment_name { in_block=1; next }
  in_block && $1 == "Host" { in_block=0 }
  !in_block' "$SSH_CONFIG.bak" > "$SSH_CONFIG"

if ! grep -q "^Host $DEPLOYMENT_NAME$" "$SSH_CONFIG"; then
  if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null; then
      if [ ! -f "$SSH_HOME/.ssh/$(basename "$KEY_FILE_PATH")" ]; then
        cp "$KEY_FILE_PATH" "$SSH_HOME/.ssh"
      fi
      PLATFORM_KEY_FILE_PATH="$win_userprofile\\.ssh\\$(basename "$KEY_FILE_PATH")"
  else
      PLATFORM_KEY_FILE_PATH="$KEY_FILE_PATH"
  fi
  echo "Adding SSH configuration for $DEPLOYMENT_NAME"
  {
    echo "Host $DEPLOYMENT_NAME"
    echo "  HostName $URL"
    echo "  User $USER"
    echo "  IdentityFile $PLATFORM_KEY_FILE_PATH"
    echo "  StrictHostKeyChecking no"
  } >> "$SSH_CONFIG"
else
  echo "SSH configuration for $DEPLOYMENT_NAME already exists"
fi

# Ensure the ssh-agent is running
eval "$(ssh-agent -s)"
ssh-add "$KEY_FILE_PATH"

echo ""
echo "INSTRUCTIONS"
echo "====================================================================================="
echo "1 - Install SSH plugin or go to Remote Explorer's SSH section."
echo "2 - Select SSH config file location if needed."
echo "3 - Activate dev-server-[YOUR_HOSTNAME] SSH"