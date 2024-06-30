#!/bin/bash

SCRIPT_DIR=$(dirname $(realpath "$0"))

# Check if the correct number of arguments are provided
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <docker-compose-file-path>"
    exit 1
fi

# Source Docker Compose file path
SOURCE_FILE="$1"

# Check if the source file exists and is readable
if [[ ! -r "$SOURCE_FILE" ]]; then
    echo "Error: The file '$SOURCE_FILE' does not exist or is not readable."
    exit 1
fi

# Check if our system has a GPU. If it does, we don't need to do anything
if [[ -z "$($SCRIPT_DIR/gpu_check.sh)" ]]; then
    echo "$SOURCE_FILE"
    exit 0
fi

# Create a temporary file
TEMP_FILE=$(mktemp /tmp/docker-compose.XXXXXX.yml)

# Copy the contents of the source file to the temporary file
cp "$SOURCE_FILE" "$TEMP_FILE"

# Strip out the GPU-related lines from the temporary file
sed -i '/deploy:/,/capabilities: \[gpu\]/d' "$TEMP_FILE"
sed -i '/runtime: nvidia/d' "$TEMP_FILE"
sed -i '/NVIDIA_VISIBLE_DEVICES/d' "$TEMP_FILE"
sed -i '/NVIDIA_DRIVER_CAPABILITIES/d' "$TEMP_FILE"

# Echo the path to the new file
echo "$TEMP_FILE"
