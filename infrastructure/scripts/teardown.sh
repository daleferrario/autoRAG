#!/bin/bash

# Function to display usage
usage() {
  echo "Usage: $0 requires a deployed stack."
  exit 1
}

# Check if .status file exists
if [ ! -f .status ]; then
  echo ".status file not found!"
  exit 1
fi

source .status

if [ -n "$LOCAL" ]; then
  echo local deployment found
  docker stop ollama chromadb autorag
  docker rm ollama chromadb autorag
  rm .status
  exit 1
fi
# Check if mandatory arguments are provided
if [ -z "$STACK_NAME" ] || [ -z "$REGION" ]; then
  usage
fi

# Create CloudFormation stack
aws cloudformation delete-stack \
  --stack-name "$STACK_NAME" \
  --region "$REGION"

# Wait for the stack to be deleted
aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"

# Check if stack still exists
STACK_STATUS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" --query "Stacks[0].StackStatus" --output text 2>/dev/null)

if [ $? -ne 0 ]; then
  echo "Stack $STACK_NAME has been successfully deleted."
else
  echo "Stack $STACK_NAME status: $STACK_STATUS"
fi

# Delete .status file
rm .status