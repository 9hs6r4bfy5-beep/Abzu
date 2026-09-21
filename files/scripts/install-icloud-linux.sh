#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing icloud-linux ---"

# Clone the repository to a system-wide location
git clone --depth 1 https://github.com/IsmaeelAkram/icloud-linux.git /usr/local/share/icloud-linux

# Make the icloudctl helper executable
chmod +x /usr/local/share/icloud-linux/icloudctl

# Create a symlink so it's available on PATH
ln -sf /usr/local/share/icloud-linux/icloudctl /usr/local/bin/icloudctl

echo "--- icloud-linux installed. Run 'icloudctl quickstart ~/iCloud' after first login. ---"
