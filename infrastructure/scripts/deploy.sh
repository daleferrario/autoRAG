#!/bin/bash

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Function to display usage
usage() {
  echo "Usage: $0 -n <stack-name> -k <keypair> [-i <ec2-instanct-type> -m <llm-model-name> -r <aws-region-name> ]"
  exit 1
}

# Parse command-line arguments
while getopts ":n:k:i:m:r:l" opt; do
  case $opt in
    n)
      STACK_NAME=$OPTARG
      ;;
    k)
      KEY_PAIR=$OPTARG
      ;;
    i)
      INSTANCE_TYPE=$OPTARG
      ;;
    m)
      LLM_MODEL_NAME=$OPTARG
      ;;
    r)
      AWS_REGION_NAME=$OPTARG
      ;;
    l)
      LOCAL=true
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

# Local deployment mode
if [ -n "$LOCAL" ]; then
  echo "local deployment"
  docker pull ollama/ollama:latest
  docker run --rm -d -v ollama:/root/.ollama -p 11434:11434 --name ollama ollama/ollama
  while [ $(docker inspect -f {{.State.Running}} ollama) != "true" ]; do
    echo "Waiting for container to be up..."
    sleep 1
  done
  if [ -z "$LLM_MODEL_NAME"]; then
    LLM_MODEL_NAME="tinydolphin"
  fi
  docker exec ollama ollama run ${LLM_MODEL_NAME}
  # chroma
  docker pull chromadb/chroma
  docker run --rm -d -p 8000:8000 --name chromadb chromadb/chroma
  # app
  # docker pull ajferrario/autorag:latest
  # DATA_PATH=$(dirname "$(dirname "$SCRIPT_DIR")")
  # docker run --rm -it -v $DATA_PATH/data:/data --network host --name autorag ajferrario/autorag:latest
  echo "LOCAL=true" >> $SCRIPT_DIR/.status
  echo "Stack information written to .status file"
  exit 1
fi
# Check if mandatory arguments are provided
if [ -z "$STACK_NAME" ] || [ -z "$KEY_PAIR" ]; then
  usage
fi
if [ -z "$LLM_MODEL_NAME" ]; then
  LLM_MODEL_NAME="tinydolphin"
fi
if [ -n "$AWS_REGION_NAME" ]; then
  REGION=$AWS_REGION_NAME
else
  REGION=$(aws configure get region)
fi
# Create CloudFormation stack
aws cloudformation create-stack \
  --stack-name "$STACK_NAME" \
  --template-body "file://$(dirname $SCRIPT_DIR)/templates/autoRAG.yml" \
  --parameters \
  ParameterKey=KeyPair,ParameterValue=$KEY_PAIR \
  ParameterKey=InstanceType,ParameterValue=$INSTANCE_TYPE \
  ParameterKey=ModelName,ParameterValue=$LLM_MODEL_NAME \
  --region "$REGION"

# Wait for the stack to be created
aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME" --region "$REGION"

# Output the stack status
aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query "Stacks[0].StackStatus" --output text --region "$REGION"

# Write status file
echo "STACK_NAME=\"$STACK_NAME\"" > $SCRIPT_DIR/.status
echo "REGION=\"$REGION\"" >> $SCRIPT_DIR/.status
echo "Stack information written to .status file"