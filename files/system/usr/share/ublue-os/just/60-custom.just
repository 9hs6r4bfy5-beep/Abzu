# Install rEFInd boot manager (requires sudo)
install-refind:
    #!/usr/bin/bash
    set -euo pipefail
    sudo /usr/local/share/abzu/install-refind.sh

# Install PC Cartridge System components (requires sudo)
install-cartridge:
    #!/usr/bin/bash
    set -euo pipefail
    sudo /usr/local/share/abzu/install-cartridge.sh

# Run Fono's setup wizard
fono-setup:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Running Fono setup wizard..."
    fono setup

# Install and authenticate icloud-cli-tools
icloud-tools-setup:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Setting up icloud-cli-tools..."
    python3 -m venv ~/.local/share/icloud-cli-tools-venv
    ~/.local/share/icloud-cli-tools-venv/bin/pip install --upgrade pip
    ~/.local/share/icloud-cli-tools-venv/bin/pip install icloud-cli-tools
    echo ""
    echo "Installation complete. To authenticate, run:"
    echo "  ~/.local/share/icloud-cli-tools-venv/bin/icloud --help"
    echo ""
    echo "You will be prompted for your Apple ID and an app-specific password."

# Set up Zaparoo user service
zaparoo-setup:
    #!/usr/bin/bash
    set -euo pipefail
    /usr/local/bin/zaparoo -install service
    /usr/local/bin/zaparoo -install desktop
    systemctl --user daemon-reload
    systemctl --user enable --now zaparoo.service
    echo "Zaparoo service installed and started."
    echo "For NFC hardware support, run: sudo /usr/local/bin/zaparoo -install hardware"

# Enable the Ground Station user service
ground-station-setup:
    #!/usr/bin/bash
    set -euo pipefail
    systemctl --user daemon-reload
    systemctl --user enable --now ground-station.service
    echo "Ground Station enabled at http://localhost:7000"
