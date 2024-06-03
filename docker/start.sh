#!/bin/sh
apt-get -y update
apt-get -y install curl
curl -fsSL https://ollama.com/install.sh | sh
ollama serve