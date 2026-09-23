# Install rEFInd boot manager
install-refind:
    #!/usr/bin/bash
    set -euo pipefail
    /usr/local/share/abzu/install-refind.sh

# Install PC Cartridge System components
install-cartridge:
    #!/usr/bin/bash
    set -euo pipefail
    /usr/local/share/abzu/install-cartridge.sh
