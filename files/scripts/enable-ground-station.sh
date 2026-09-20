#!/usr/bin/env bash
set -euo pipefail

# This script is placed in /etc/skel and is intended to be run manually
# or via a first-login mechanism. It enables the Ground Station user service.

systemctl --user daemon-reload
systemctl --user enable --now ground-station.service

echo "Ground Station service enabled. It will be available at http://localhost:7000"
