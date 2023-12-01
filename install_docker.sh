#!/bin/bash

# cannot be run as root
if [ "$EUID" -eq 0 ]; then
    echo "Please run without sudo"
    exit 1
fi

agent_user=$(whoami)

# Install docker from script
curl -fsSL https://get.docker.com | bash -

# add docker group to current user
sudo usermod -aG docker $agent_user

# activate docker group
newgrp docker

# Install docker-compose
sudo apt install docker-compose -y

# Test docker installation and correct user permissions
docker ps || echo "Insufficient permissions to run docker. Please log out and log back in."

