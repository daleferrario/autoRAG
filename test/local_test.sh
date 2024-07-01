#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get the directory of the script and the root of the git repository
SCRIPT_DIR=$(dirname $(realpath "$0"))
ROOT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)

# Function to display usage
usage() {
  echo "Usage: $0 -n <deployment-name> -c <customer-env-file-path>"
  exit 1
}

# Parse command-line arguments
echo "Arguments:"
while getopts ":e:" opt; do
  echo "-$opt $OPTARG"
  case $opt in
    e)
      ENV_FILE="$OPTARG"
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

if [ -z "$ENV_FILE" ] ; then
  ENV_FILE="$SCRIPT_DIR/discord_test.env"
fi
# Export the environment file
export ENV_FILE
echo "Using ENV_FILE: $ENV_FILE"

# Generate Docker Compose paths
DOCKER_COMPOSE_SHARED_PATH=$("$ROOT_DIR/scripts/app/generate_docker_compose.sh" "$ROOT_DIR/docker-compose-shared.yml")
DOCKER_COMPOSE_CUSTOMER_PATH=$("$ROOT_DIR/scripts/app/generate_docker_compose.sh" "$ROOT_DIR/docker-compose-customer.yml")

# Function to clean up background processes
cleanup() {
    echo "Stopping services and logging..."
    docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" --env-file "$ENV_FILE" down -v
    docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" down -v
    kill $SHARED_LOG_PID
    kill $CUSTOMER_LOG_PID
    echo "Cleanup complete."
}

# Trap SIGINT and SIGTERM to ensure cleanup is called
trap cleanup SIGINT SIGTERM

# Clean environment
echo "Cleaning up environment"
docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" --env-file "$ENV_FILE" down -v --remove-orphans
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" down -v --remove-orphans

# Pull latest images
echo "Pulling latest images"
docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" --env-file "$ENV_FILE" pull
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" pull

# Deploy shared services
echo "Deploying shared services"
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" up -d
docker compose -f "$DOCKER_COMPOSE_SHARED_PATH" logs -f > "$SCRIPT_DIR/docker-compose-shared.log" &
SHARED_LOG_PID=$!
echo "Waiting for 'ollama' service to be up and responding..."
until docker exec ollama ollama ps &> /dev/null; do
    echo "Waiting for 'ollama' to respond..."
    sleep 5
done
echo "'ollama' service is up and responding."

# Load customer data
echo "Loading data"
docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" --env-file "$ENV_FILE" up data_loader -d
docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" --env-file "$ENV_FILE" logs -f > "$SCRIPT_DIR/docker-compose-customer.log" &
CUSTOMER_LOG_PID=$!
while docker ps | grep -q "data_loader"; do
    echo "Waiting for 'data_loader' to exit..."
    sleep 5
done
echo "data_loader has exited."

# Deploy customer query_server
echo "Deploying query_server"
docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" --env-file "$ENV_FILE" up query_server -d
docker compose -f "$DOCKER_COMPOSE_CUSTOMER_PATH" --env-file "$ENV_FILE" logs -f >> "$SCRIPT_DIR/docker-compose-customer.log" &

# Wait for all background logging processes to end
wait $SHARED_LOG_PID
wait $CUSTOMER_LOG_PID
