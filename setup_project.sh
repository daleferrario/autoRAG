#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to prompt user for y/n response
prompt_user() {
    while true; do
        read -p "$1 (y/n): " yn
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to check DockerHub repository access
check_dockerhub_access() {
    local repo_name="$1"
    local test_image="hello-world"
    local test_tag="test"

    echo "Checking push access to $repo_name..."

    # Pull the test image
    docker pull $test_image

    # Tag the test image
    docker tag $test_image $repo_name:$test_tag

    # Try to push the test image
    if docker push $repo_name:$test_tag; then
        echo "You have push access to $repo_name."
        
        # # Remove the tag from DockerHub using hub-tool
        # echo "Removing the tag from DockerHub..."
        # hub-tool tag rm $repo_name:$test_tag
    else
        echo "You do not have push access to $repo_name."
    fi

    # Remove the local tags
    docker rmi $repo_name:$test_tag
    docker rmi $test_image
}

# Update the package repository
sudo apt update

# AWS CLI installation
if prompt_user "Do you want to install AWS CLI?"; then
    # Install necessary dependencies for AWS CLI if not already installed
    if ! command_exists curl || ! command_exists unzip; then
        sudo apt install -y unzip curl
    fi

    # Check if AWS CLI is installed
    if ! command_exists aws; then
        # Download the AWS CLI version 2 installation file
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

        # Unzip the downloaded file
        unzip awscliv2.zip

        # Run the AWS CLI install program
        sudo ./aws/install

        # Verify the AWS CLI installation
        aws --version

        # Cleanup AWS CLI installation files
        rm -rf awscliv2.zip aws

        # Configure AWS CLI
        echo "Configuring AWS CLI..."
        aws configure
    else
        echo "AWS CLI is already installed."
    fi
else
    echo "Skipping AWS CLI installation."
fi

# Pipenv installation
if prompt_user "Do you want to install Pipenv?"; then
    # Install necessary dependencies for Pipenv if not already installed
    if ! command_exists pip3; then
        sudo apt install -y python3-pip
    fi

    # Check if Pipenv is installed
    if ! command_exists pipenv; then
        # Install Pipenv using pip
        pip3 install --user pipenv

        # Verify the Pipenv installation
        pipenv --version
    else
        echo "Pipenv is already installed."
    fi
else
    echo "Skipping Pipenv installation."
fi

# Docker installation
if prompt_user "Do you want to install Docker?"; then
    # Install Docker if not already installed
    if ! command_exists docker; then
        # Remove old versions
        sudo apt remove -y docker docker-engine docker.io containerd runc

        # Set up the repository
        sudo apt install -y ca-certificates gnupg

        # Add Docker’s official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Set up the stable repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
          $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Install Docker Engine
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io

        # Verify Docker installation
        sudo systemctl start docker
        sudo systemctl enable docker
        docker --version
    else
        echo "Docker is already installed."
    fi
else
    echo "Skipping Docker installation."
fi

# Docker Compose installation
if prompt_user "Do you want to install Docker Compose?"; then
    # Install Docker Compose if not already installed
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        # Download the current stable release of Docker Compose
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
        sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

        # Apply executable permissions to the binary
        sudo chmod +x /usr/local/bin/docker-compose

        # Create a symbolic link to use 'docker compose'
        sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

        # Verify Docker Compose installation
        docker compose version
    else
        echo "Docker Compose is already installed."
    fi
else
    echo "Skipping Docker Compose installation."
fi

# Docker login
if prompt_user "Do you want to log into Docker?"; then
    echo "Please log into Docker:"
    sudo docker login
else
    echo "Skipping Docker login."
fi

# Check push access to DockerHub repositories
if prompt_user "Do you want to check push access to Distill DockerHub repositories?"; then
    check_dockerhub_access "ajferrario/distill-discord-bot"
    check_dockerhub_access "ajferrario/distill-slack-app"
else
    echo "Skipping DockerHub repository access check."
fi

# Create .distill_keys directory if it doesn't exist
mkdir -p ~/.distill_keys

# Prompt user to provide keys or skip
if prompt_user "Do you want to provide paths for needed key files now?"; then
    # Prompt user for bot.key path
    read -p "Please provide the path to bot.key file for discord_bot: " DISCORD_BOT_KEY_PATH
    if [ -f "$DISCORD_BOT_KEY_PATH" ]; then
        cp "$DISCORD_BOT_KEY_PATH" ~/.distill_keys/
        echo "bot.key has been copied to ~/.distill_keys/"
        echo "export DISCORD_BOT_KEY=$(cat ~/.distill_keys/bot.key)" >> ~/.bashrc
        echo "DISCORD_BOT_KEY environment variable has been added to .bashrc"
    else
        echo "bot.key file not found at the provided path."
    fi
    # Prompt user for slack_bot_token path
    read -p "Please provide the path to slack_bot_token file: " SLACK_BOT_TOKEN_PATH
    if [ -f "$SLACK_BOT_TOKEN_PATH" ]; then
        cp "$SLACK_BOT_TOKEN_PATH" ~/.distill_keys/
        echo "slack_bot_token has been copied to ~/.distill_keys/"
        echo "export SLACK_BOT_TOKEN=$(cat ~/.distill_keys/slack_bot_token)" >> ~/.bashrc
        echo "SLACK_BOT_TOKEN environment variable has been added to .bashrc"
    else
        echo "slack_bot_token file not found at the provided path."
    fi
    # Prompt user for slack_app_token path
    read -p "Please provide the path to slack_app_token file: " SLACK_APP_TOKEN_PATH
    if [ -f "$SLACK_APP_TOKEN_PATH" ]; then
        cp "$SLACK_APP_TOKEN_PATH" ~/.distill_keys/
        echo "slack_app_token has been copied to ~/.distill_keys/"
        echo "export SLACK_APP_TOKEN=$(cat ~/.distill_keys/slack_app_token)" >> ~/.bashrc
        echo "SLACK_APP_TOKEN environment variable has been added to .bashrc"
    else
        echo "slack_app_token file not found at the provided path."
    fi
    # Prompt user for DDNS_API_KEY path
    read -p "Please provide the path to ddns_api.key file: " DDNS_API_KEY_PATH
    if [ -f "$DDNS_API_KEY_PATH" ]; then
        cp "$DDNS_API_KEY_PATH" ~/.distill_keys/
        echo "ddns_api.key has been copied to ~/.distill_keys/"
        echo "export DDNS_API_KEY=$(cat ~/.distill_keys/ddns_api.key)" >> ~/.bashrc
        echo "DDNS_API_KEY environment variable has been added to .bashrc"
    else
        echo "ddns_api.key file not found at the provided path."
    fi
    # Prompt user for CF_ORIGIN_CERT path
    read -p "Please provide the path to distill-ai-origin-cert.pem file: " CF_CERT_PATH
    if [ -f "$CF_CERT_PATH" ]; then
        cp "$CF_CERT_PATH" ~/.distill_keys/
        echo "ddns_api.key has been copied to ~/.distill_keys/"
        echo "export CF_CERT_PATH=$CF_CERT_PATH" >> ~/.bashrc
        echo "CF_CERT_PATH environment variable has been added to .bashrc"
    else
        echo "distill-ai-origin-cert.pem file not found at the provided path."
    fi
    # Prompt user for CF_ORIGIN_PRIVATE_KEY path
    read -p "Please provide the path to distill-ai-origin-private.pem file: " CF_PRIVATE_KEY_PATH
    if [ -f "$CF_PRIVATE_KEY_PATH" ]; then
        cp "$CF_PRIVATE_KEY_PATH" ~/.distill_keys/
        echo "ddns_api.key has been copied to ~/.distill_keys/"
        echo "export CF_PRIVATE_KEY_PATH=$CF_PRIVATE_KEY_PATH" >> ~/.bashrc
        echo "CF_PRIVATE_KEY_PATH environment variable has been added to .bashrc"
    else
        echo "distill-ai-origin-private.pem file not found at the provided path."
    fi
else
    echo "You chose to skip providing keys."
    echo "Please ensure you place the 'bot.key', 'slack_app_token', 'slack_bot_token', 'distill-ai-origin-cert.pem' and 'distill-ai-origin-private.pem' files in the ~/.distill_keys/ directory."
    echo "Then add the following lines to your ~/.bashrc file:"
    echo "export DISCORD_BOT_KEY=\$(cat ~/.distill_keys/bot.key)"
    echo "export SLACK_BOT_TOKEN=\$(cat ~/.distill_keys/slack_bot_token)"
    echo "export SLACK_APP_TOKEN=\$(cat ~/.distill_keys/slack_app_token)"
    echo "export DDNS_API_KEY=\$(cat ~/.distill_keys/ddns_api.key)"
    echo "export CF_CERT_PATH=~/.distill_keys/distill-ai-origin-cert.pem"
    echo "export CF_PRIVATE_KEY_PATH=~/.distill_keys/distill-ai-origin-private.pem"
    echo "The project will not function correctly without these keys."
fi

# Inform user to reload .bashrc to apply the changes
echo "Please run 'source ~/.bashrc' to apply the environment variable changes."
