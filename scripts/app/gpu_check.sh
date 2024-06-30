#!/bin/bash

# Initialize NO_GPU variable
NO_GPU="-no-gpu"

# Check if nvidia-smi is installed
if command -v nvidia-smi &> /dev/null; then
    # Run nvidia-smi and capture the output
    if nvidia-smi > /dev/null 2>&1; then
        # Check if GPU is detected
        if nvidia-smi | grep -q "NVIDIA-SMI"; then
            # NVIDIA GPU detected
            NO_GPU=""
        else
            # No NVIDIA GPU detected
            :
        fi
    else
        # nvidia-smi command failed
        :
    fi
else
    # nvidia-smi is not installed
    :
fi

# Output the value of NO_GPU variable
echo "$NO_GPU"
