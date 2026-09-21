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
