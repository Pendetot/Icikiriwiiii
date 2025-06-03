#!/bin/bash

# =============================================================================
# Simplified Windows Docker Installer for rdpInstaller.js
# =============================================================================

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root!"
   exit 1
fi

# Function to install Docker if not present
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "Installing Docker..."
        
        # Update system
        if [[ -f /etc/debian_version ]]; then
            apt update -y
            apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
            
            # Add Docker GPG key and repository
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
            echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            apt update -y
            apt install -y docker-ce docker-ce-cli containerd.io
            
        elif [[ -f /etc/redhat-release ]]; then
            yum update -y
            yum install -y yum-utils
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            yum install -y docker-ce docker-ce-cli containerd.io
        fi
        
        # Start Docker service
        systemctl start docker
        systemctl enable docker
        
        echo "Docker installed successfully"
    fi
}

# Read configuration from stdin (sent by rdpInstaller.js)
read -r WINDOWS_ID
read -r RAM_INPUT
read -r CPU_INPUT  
read -r STORAGE_INPUT
read -r PASSWORD_INPUT
read -r IS_ARM
read -r SUPPORTS_KVM

# Map Windows ID to version
case $WINDOWS_ID in
    1) VERSION="11";;
    2) VERSION="11l";;
    3) VERSION="11e";;
    4) VERSION="10";;
    5) VERSION="10l";;
    6) VERSION="10e";;
    7) VERSION="8e";;
    8) VERSION="7u";;
    9) VERSION="vu";;
    10) VERSION="xp";;
    11) VERSION="2k";;
    12) VERSION="2025";;
    13) VERSION="2022";;
    14) VERSION="2019";;
    15) VERSION="2016";;
    16) VERSION="2012";;
    17) VERSION="2008";;
    18) VERSION="2003";;
    *) VERSION="10";;
esac

# Set specifications
RAM_SIZE="${RAM_INPUT}G"
CPU_CORES_SET=$CPU_INPUT
DISK_SIZE="${STORAGE_INPUT}G"
USERNAME="Administrator"
PASSWORD="$PASSWORD_INPUT"

# Detect architecture and KVM support info
ARCH_INFO=""
KVM_INFO=""

if [[ "$IS_ARM" == "1" ]]; then
    ARCH_INFO="ARM architecture detected"
else
    ARCH_INFO="x86_64 architecture detected"
fi

if [[ "$SUPPORTS_KVM" == "1" ]]; then
    KVM_INFO="KVM acceleration available"
else
    KVM_INFO="KVM acceleration not available (using software emulation)"
fi

echo "System Information:"
echo "  $ARCH_INFO"
echo "  $KVM_INFO"
echo "Configuration:"
echo "  RAM: $RAM_SIZE"
echo "  CPU: $CPU_CORES_SET cores"
echo "  Storage: $DISK_SIZE"

# Install Docker if needed
install_docker

# Create working directory
mkdir -p /opt/windows-docker
cd /opt/windows-docker

# Remove existing container if present
docker rm -f windows 2>/dev/null || true

# Configure Docker run parameters based on architecture and KVM support
DOCKER_PARAMS=""

if [[ "$SUPPORTS_KVM" == "1" ]]; then
    DOCKER_PARAMS="--device=/dev/kvm"
    echo "  Using KVM acceleration for better performance"
else
    echo "  Using software emulation (slower performance)"
fi

if [[ "$IS_ARM" == "1" ]]; then
    echo "  Optimized for ARM architecture"
else
    echo "  Optimized for x86_64 architecture"
fi

echo "Starting Windows container..."

# Run Windows container with conditional KVM support
if [[ "$SUPPORTS_KVM" == "1" ]]; then
    # With KVM acceleration
    docker run -d \
        --name windows \
        --device=/dev/kvm \
        --device=/dev/net/tun \
        --cap-add NET_ADMIN \
        -p 8006:8006 \
        -p 3389:3389/tcp \
        -p 3389:3389/udp \
        -v "${PWD}/windows:/storage" \
        -v "${PWD}/shared:/data" \
        -e VERSION="${VERSION}" \
        -e USERNAME="${USERNAME}" \
        -e PASSWORD="${PASSWORD}" \
        -e RAM_SIZE="${RAM_SIZE}" \
        -e CPU_CORES="${CPU_CORES_SET}" \
        -e DISK_SIZE="${DISK_SIZE}" \
        -e LANGUAGE="English" \
        -e REGION="en-US" \
        -e KEYBOARD="en-US" \
        --restart always \
        --stop-timeout 120 \
        dockurr/windows
else
    # Without KVM acceleration (software emulation)
    docker run -d \
        --name windows \
        --device=/dev/net/tun \
        --cap-add NET_ADMIN \
        -p 8006:8006 \
        -p 3389:3389/tcp \
        -p 3389:3389/udp \
        -v "${PWD}/windows:/storage" \
        -v "${PWD}/shared:/data" \
        -e VERSION="${VERSION}" \
        -e USERNAME="${USERNAME}" \
        -e PASSWORD="${PASSWORD}" \
        -e RAM_SIZE="${RAM_SIZE}" \
        -e CPU_CORES="${CPU_CORES_SET}" \
        -e DISK_SIZE="${DISK_SIZE}" \
        -e LANGUAGE="English" \
        -e REGION="en-US" \
        -e KEYBOARD="en-US" \
        --restart always \
        --stop-timeout 120 \
        dockurr/windows
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s ipinfo.io/ip 2>/dev/null || echo "YOUR_SERVER_IP")

echo ""
echo "========================================="
echo "         INSTALLATION COMPLETE"
echo "========================================="
echo "Web Viewer: http://${SERVER_IP}:8006"
echo "RDP: ${SERVER_IP}:3389"
echo "Username: ${USERNAME}"
echo "Password: ${PASSWORD}"
echo ""
echo "Container started successfully!"
echo "RDP Server is now running on port 3389"
echo "Web interface available at http://${SERVER_IP}:8006"
echo "========================================="