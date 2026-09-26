#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing Zaparoo Core ---"

REPO="ZaparooProject/zaparoo-core"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"

echo "Querying latest release from ${REPO}..."
RELEASE_JSON=$(curl -fsSL "${API_URL}")

# Tag comes through as e.g. "v2.18.0"; strip the leading 'v' for the
# asset filename, which uses the bare version number.
TAG=$(echo "${RELEASE_JSON}" | jq -r '.tag_name')
VERSION="${TAG#v}"
echo "Latest release: ${TAG} (version ${VERSION})"

ASSET_NAME="zaparoo-linux_amd64-${VERSION}.tar.gz"
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/${ASSET_NAME}"

echo "Downloading ${ASSET_NAME}..."
mkdir -p /tmp/zaparoo-install
cd /tmp/zaparoo-install

if ! curl -fL -o "${ASSET_NAME}" "${DOWNLOAD_URL}"; then
    echo "Download failed: ${DOWNLOAD_URL}"
    echo "Assets available in this release:"
    echo "${RELEASE_JSON}" | jq -r '.assets[].name'
    exit 1
fi

# Verify it's a gzip archive by checking the magic bytes (1f 8b).
FIRST_BYTES=$(od -A n -t x1 -N 2 "${ASSET_NAME}" | tr -d ' \n')
if [ "${FIRST_BYTES}" != "1f8b" ]; then
    echo "Error: downloaded file does not begin with gzip magic bytes (got ${FIRST_BYTES})."
    exit 1
fi

echo "Extracting archive..."
tar -xzf "${ASSET_NAME}"

# The archive contains a single 'zaparoo' binary.
if [ ! -f "zaparoo" ]; then
    echo "Error: no 'zaparoo' binary found in the extracted archive."
    ls -la
    exit 1
fi

install -m 0755 zaparoo /usr/local/bin/zaparoo
echo "Zaparoo Core installed to /usr/local/bin/zaparoo"

cd /
rm -rf /tmp/zaparoo-install

echo "--- Zaparoo Core installed ---"
