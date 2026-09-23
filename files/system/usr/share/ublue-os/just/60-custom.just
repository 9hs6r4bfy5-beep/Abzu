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
