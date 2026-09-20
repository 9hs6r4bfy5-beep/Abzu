# Run Fono's setup wizard
fono-setup:
    #!/usr/bin/bash
    set -euo pipefail
    echo "Running Fono setup wizard..."
    fono setup
