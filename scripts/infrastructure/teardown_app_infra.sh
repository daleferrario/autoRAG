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

# Check if .state file exists
echo "Collecting .state file"
STATE_PATH="$STATE_DIR/$DEPLOYMENT_NAME.state"
if [ ! -f "$STATE_PATH" ]; then
  echo "$DEPLOYMENT_NAME.state not found!"
  exit 1
fi
source $STATE_PATH

# Check if mandatory arguments are provided
if [ -z "$DEPLOYMENT_NAME" ] || [ -z "$REGION" ]; then
  usage
fi

# Create CloudFormation stack
echo "Deleting deployment stack"
aws cloudformation delete-stack \
  --stack-name "$DEPLOYMENT_NAME" \
  --region "$REGION"

# Wait for the stack to be deleted
echo "Waiting for stack to be deleted"
aws cloudformation wait stack-delete-complete --stack-name "$DEPLOYMENT_NAME" --region "$REGION"


# Delete .state file
echo "Cleaning up state file at: $STATE_PATH"
rm "$STATE_PATH"