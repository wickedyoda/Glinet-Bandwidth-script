#!/bin/sh
set -e
INSTALL_DIR=/usr/local/sbin
SCRIPT=glinet-vlan-qos.sh
SETUP_SCRIPT=glinet-vlan-qos-setup.sh
REMOTE=https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/master
mkdir -p ${INSTALL_DIR}
curl -fsSL "${REMOTE}/${SCRIPT}" -o "${INSTALL_DIR}/${SCRIPT}"
chmod +x "${INSTALL_DIR}/${SCRIPT}"
curl -fsSL "${REMOTE}/${SETUP_SCRIPT}" -o "${INSTALL_DIR}/${SETUP_SCRIPT}"
chmod +x "${INSTALL_DIR}/${SETUP_SCRIPT}"
echo "Installed ${INSTALL_DIR}/${SCRIPT} and ${INSTALL_DIR}/${SETUP_SCRIPT}"
echo "Run '${INSTALL_DIR}/${SETUP_SCRIPT}' to configure QoS"