#!/bin/sh
set -e
INSTALL_DIR=/usr/local/sbin
SCRIPT=glinet-vlan-qos.sh
REMOTE=https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/main/${SCRIPT}
mkdir -p ${INSTALL_DIR}
curl -fsSL "${REMOTE}" -o "${INSTALL_DIR}/${SCRIPT}"
chmod +x "${INSTALL_DIR}/${SCRIPT}"
"${INSTALL_DIR}/${SCRIPT}" install
"${INSTALL_DIR}/${SCRIPT}" start
echo "Installed ${INSTALL_DIR}/${SCRIPT}"
