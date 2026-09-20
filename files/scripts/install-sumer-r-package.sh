#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing sumer R package ---"

# Install the sumer package from CRAN.
# This will compile the package and its dependencies.
Rscript -e 'install.packages("sumer", repos = "https://cran.r-project.org", dependencies = TRUE)'

echo "--- sumer package installed ---"
