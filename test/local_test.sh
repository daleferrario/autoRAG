#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get the directory of the script and the root of the git repository
SCRIPT_DIR=$(dirname $(realpath "$0"))
ROOT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)

# Function to display usage
usage() {
  echo "Usage: $0 [-c <customer1-env-file-path> -d <customer2-env-file-path> -w <web-infra-env-file-path>]"
  exit 1
}

# Parse command-line arguments
echo "Arguments:"
while getopts ":c:d:w:" opt; do
  echo "-$opt $OPTARG"
  case $opt in
    c)
      CUSTOMER1_ENV_FILE="$OPTARG"
      ;;
    d)
      CUSTOMER2_ENV_FILE="$OPTARG"
      ;;
    w)
      WEB_INFRA_ENV_FILE="$OPTARG"
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

if [ -z "$CUSTOMER1_ENV_FILE" ] ; then
  CUSTOMER1_ENV_FILE="$SCRIPT_DIR/develop-great-managers.env"
fi
echo "Using CUSTOMER1_ENV_FILE: $CUSTOMER1_ENV_FILE"
source $CUSTOMER1_ENV_FILE
CUSTOMER1_ID=$CUSTOMER_ID

if [ -z "$CUSTOMER2_ENV_FILE" ] ; then
  CUSTOMER2_ENV_FILE="$SCRIPT_DIR/test-customer.env"
fi
echo "Using CUSTOMER2_ENV_FILE: $CUSTOMER2_ENV_FILE"
source $CUSTOMER2_ENV_FILE
CUSTOMER2_ID=$CUSTOMER_ID

if [ -z "$WEB_INFRA_ENV_FILE" ] ; then
  WEB_INFRA_ENV_FILE="$SCRIPT_DIR/web_infra.env"
fi
# Export the web infra environment file
export WEB_INFRA_ENV_FILE
echo "Using WEB_INFRA_ENV_FILE: $WEB_INFRA_ENV_FILE"

# Generate Docker Compose paths
DOCKER_COMPOSE_SHARED_PATH=$("$ROOT_DIR/scripts/app/generate_docker_compose.sh" "$ROOT_DIR/docker-compose-shared.yml")
DOCKER_COMPOSE_CUSTOMER_PATH="$ROOT_DIR/docker-compose-customer.yml"
DOCKER_COMPOSE_WEB_INFRA_PATH="$ROOT_DIR/docker-compose-web-infra.yml"

# Function to clean up background processes
cleanup() {
    echo "Stopping services and logging..."
    CUSTOMER_ID=$CUSTOMER1_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER1_ID" down -v
    CUSTOMER_ID=$CUSTOMER2_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER2_ID" down -v
    docker compose -f "$DOCKER_COMPOSE_WEB_INFRA_PATH" --env-file $WEB_INFRA_ENV_FILE  down -v
    docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" down -v
    kill $CUSTOMER1_LOG_PID
    kill $CUSTOMER2_LOG_PID
    kill $SHARED_LOG_PID
    kill $WEB_INFRA_LOG_PID
    echo "Cleanup complete."
}

# Trap SIGINT and SIGTERM to ensure cleanup is called
trap cleanup SIGINT SIGTERM

# Clean environment
echo "Cleaning up environment"
CUSTOMER_ID=$CUSTOMER1_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER1_ID" down -v
CUSTOMER_ID=$CUSTOMER2_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER2_ID" down -v
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" down -v
docker compose -f "$DOCKER_COMPOSE_WEB_INFRA_PATH" --env-file $WEB_INFRA_ENV_FILE down -v


# Pull latest images
echo "Pulling latest images"
CUSTOMER_ID=$CUSTOMER1_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" pull
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" pull
docker compose -f "$DOCKER_COMPOSE_WEB_INFRA_PATH" --env-file $WEB_INFRA_ENV_FILE pull

# Deploy shared services
echo "Deploying shared services"
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" up -d
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" logs -f > "$SCRIPT_DIR/docker-compose-shared.log" &
SHARED_LOG_PID=$!
while docker ps | grep -q "ollama_model_puller"; do
    echo "Waiting for 'ollama_model_puller' to exit..."
    sleep 5
done

# Deploy customer 1
echo "Deploying $CUSTOMER1_ID"
CUSTOMER_ID=$CUSTOMER1_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER1_ID" up -d
CUSTOMER_ID=$CUSTOMER1_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER1_ID" logs -f > "$SCRIPT_DIR/docker-compose-customer-$CUSTOMER1_ID.log" &
CUSTOMER1_LOG_PID=$!

# Deploy web infra
echo "Deploying web infra"
docker compose -f "$DOCKER_COMPOSE_WEB_INFRA_PATH" --env-file $WEB_INFRA_ENV_FILE  up -d
docker compose -f "$DOCKER_COMPOSE_WEB_INFRA_PATH" --env-file $WEB_INFRA_ENV_FILE logs -f > "$SCRIPT_DIR/docker-compose-web-infra.log" &
WEB_INFRA_LOG_PID=$!

# Deploy customer 2
echo "Deploying $CUSTOMER2_ID"
CUSTOMER_ID=$CUSTOMER2_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER2_ID" up -d
CUSTOMER_ID=$CUSTOMER2_ID docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" -p "$CUSTOMER2_ID" logs -f > "$SCRIPT_DIR/docker-compose-customer-$CUSTOMER2_ID.log" &
CUSTOMER2_LOG_PID=$!

