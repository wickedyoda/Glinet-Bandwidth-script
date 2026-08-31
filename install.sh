#!/bin/sh
# install.sh - One-liner installer with checksum verification
# Downloads scripts and verifies SHA256 checksums before installing
set -e

INSTALL_DIR=/usr/local/sbin
SCRIPT=glinet-vlan-qos.sh
SETUP_SCRIPT=glinet-vlan-qos-setup.sh
CHECKSUMS_FILE=checksums.txt
REMOTE=https://raw.githubusercontent.com/wickedyoda/Glinet-Bandwidth-script/master

mkdir -p "${INSTALL_DIR}"

# Download checksums file
curl -fsSL "${REMOTE}/${CHECKSUMS_FILE}" -o "/tmp/${CHECKSUMS_FILE}"

# Download scripts to temp
curl -fsSL "${REMOTE}/${SCRIPT}" -o "/tmp/${SCRIPT}"
curl -fsSL "${REMOTE}/${SETUP_SCRIPT}" -o "/tmp/${SETUP_SCRIPT}"

# Verify checksums
echo "Verifying checksums..."
cd /tmp
sha256sum -c "${CHECKSUMS_FILE}" 2>/dev/null || {
    echo "ERROR: Checksum verification failed!" >&2
    echo "The downloaded files do not match recorded checksums." >&2
    echo "This could indicate a security issue or file corruption." >&2
    exit 1
}

# Install verified scripts
cp "/tmp/${SCRIPT}" "${INSTALL_DIR}/${SCRIPT}"
cp "/tmp/${SETUP_SCRIPT}" "${INSTALL_DIR}/${SETUP_SCRIPT}"
chmod +x "${INSTALL_DIR}/${SCRIPT}"
chmod +x "${INSTALL_DIR}/${SETUP_SCRIPT}"

# Cleanup
rm -f "/tmp/${SCRIPT}" "/tmp/${SETUP_SCRIPT}" "/tmp/${CHECKSUMS_FILE}"

echo "Installed and verified ${INSTALL_DIR}/${SCRIPT} and ${INSTALL_DIR}/${SETUP_SCRIPT}"
echo "Run '${INSTALL_DIR}/${SETUP_SCRIPT}' to configure QoS"