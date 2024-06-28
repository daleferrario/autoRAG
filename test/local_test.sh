#!/bin/bash

set -e

# Get the directory of the script
SCRIPT_DIR=$(dirname $(realpath "$0"))
echo $SCRIPT_DIR

NO_GPU="-no-gpu"
# Check for GPU
if command -v nvidia-smi &> /dev/null; then
    # Run nvidia-smi and capture the output
    gpu_info=$(nvidia-smi 2>&1)
    
    # Check if nvidia-smi command ran successfully
    if [ $? -eq 0 ]; then
        # Check if GPU is detected
        if echo "$gpu_info" | grep -q "NVIDIA-SMI"; then
            echo "NVIDIA GPU detected."
            NO_GPU=""
        else
            echo "No NVIDIA GPU detected."
        fi
    else
        echo "nvidia-smi command failed."
    fi
else
    echo "nvidia-smi is not installed."
fi

# Output the value of NO_GPU variable
echo "NO_GPU is set to: $NO_GPU"


# Function to clean up background processes
cleanup() {
    echo "Stopping services and logging..."
    docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-customer"$NO_GPU".yml" --env-file "$SCRIPT_DIR/dgm_test.env" down -v
    docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-shared"$NO_GPU".yml" down -v
    kill $SHARED_LOG_PID
    kill $CUSTOMER_LOG_PID
    echo "Cleanup complete."
}

# Trap SIGINT and SIGTERM to ensure cleanup is called
trap cleanup SIGINT SIGTERM

# Clean environment
echo "Cleaning up environment"
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-customer"$NO_GPU".yml" --env-file "$SCRIPT_DIR/dgm_test.env" down -v
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-shared"$NO_GPU".yml" down -v

# Pull latest images
echo "Pulling latest images"
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-customer"$NO_GPU".yml" --env-file "$SCRIPT_DIR/dgm_test.env" pull
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-shared"$NO_GPU".yml" pull

# Deploy shared services
echo "Deploying shared services"
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-shared"$NO_GPU".yml" up -d
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-shared"$NO_GPU".yml" logs -f > "$SCRIPT_DIR/docker-compose-shared.log" &
SHARED_LOG_PID=$!
echo "Waiting for 'ollama' service to be up and responding..."
until docker exec ollama ollama ps &> /dev/null; do
    echo "Waiting for 'ollama' to respond..."
    sleep 5
done
echo "'ollama' service is up and responding."

# Load customer data
echo "Loading data"
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-customer"$NO_GPU".yml" --env-file "$SCRIPT_DIR/dgm_test.env" up data_loader -d
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-customer"$NO_GPU".yml" logs -f > "$SCRIPT_DIR/docker-compose-customer.log" &
CUSTOMER_LOG_PID=$!
while docker ps | grep -q "data_loader"; do
    echo "Waiting for 'data_loader' to exit..."
    sleep 5
done
echo "data_loader has exited."

# Deploy customer query_server
echo "Deploying query_server"
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-customer"$NO_GPU".yml" --env-file "$SCRIPT_DIR/dgm_test.env" up query_server -d
docker compose -f "$(dirname "$SCRIPT_DIR")/docker-compose-customer"$NO_GPU".yml" logs -f >> "$SCRIPT_DIR/docker-compose-customer.log" &

# Wait for all background logging processes to end
wait $SHARED_LOG_PID
wait $CUSTOMER_LOG_PID