#!/bin/sh
set -e
INSTALL_DIR=/usr/local/sbin
SCRIPT=glinet-vlan-qos.sh
SETUP_SCRIPT=glinet-vlan-qos-setup.sh
CHECKSUMS=checksums-router.txt
REMOTE=https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/master
mkdir -p "${INSTALL_DIR}"
# Download checksums
curl -fsSL "${REMOTE}/${CHECKSUMS}" -o /tmp/${CHECKSUMS}
# Download scripts
curl -fsSL "${REMOTE}/${SCRIPT}" -o /tmp/${SCRIPT}
curl -fsSL "${REMOTE}/${SETUP_SCRIPT}" -o /tmp/${SETUP_SCRIPT}
# Verify
cd /tmp
sha256sum -c ${CHECKSUMS} || {
  echo "ERROR: Checksum verification failed!" >&2
  exit 1
}
# Install
cp ${SCRIPT} ${SETUP_SCRIPT} "${INSTALL_DIR}/"
chmod +x "${INSTALL_DIR}/${SCRIPT}" "${INSTALL_DIR}/${SETUP_SCRIPT}"
rm -f /tmp/${SCRIPT} /tmp/${SETUP_SCRIPT} /tmp/${CHECKSUMS}
echo "Installed and verified ${INSTALL_DIR}/${SCRIPT} and ${INSTALL_DIR}/${SETUP_SCRIPT}"
echo "Run '${INSTALL_DIR}/${SETUP_SCRIPT}' to configure QoS"