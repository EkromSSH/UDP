#!/bin/bash
# EkromSSH UDP - One Click Installer
# IP 239 Reference
#
# ใช้:
#   bash <(curl -s https://raw.githubusercontent.com/EkromSSH/UDP/main/one-click.sh)

UDP_REPO="https://raw.githubusercontent.com/EkromSSH/UDP/main"

# Install dependencies
apt install -y wget curl screen git 2>/dev/null

# Download and run main installer
wget -q -O /tmp/udp-main.sh "${UDP_REPO}/main.sh"
chmod +x /tmp/udp-main.sh
bash /tmp/udp-main.sh
