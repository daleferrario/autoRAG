#!/bin/bash

# Initialize NO_GPU variable
NO_GPU="-no-gpu"

# Check if nvidia-smi is installed
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

export NO_GPU

# Output the value of NO_GPU variable
echo "NO_GPU is set to: $NO_GPU"
