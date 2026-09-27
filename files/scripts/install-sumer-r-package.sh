#!/usr/bin/env bash
set -euo pipefail

echo "--- Installing sumer R package ---"

# Install sumer and its hard dependencies (Depends / Imports / LinkingTo).
# Deliberately omit `dependencies = TRUE`, which would try to install every
# Suggests package of every transitive dependency and pull in hundreds of
# packages that need system libraries we do not ship.
#
# Note: install.packages() does NOT return a non-zero exit code on failure,
# so we verify the install afterwards by loading the package.

Rscript -e '
  options(
    repos = c(CRAN = "https://cloud.r-project.org"),
    warn = 1,
    Ncpus = max(1L, parallel::detectCores() - 1L)
  )
  install.packages("sumer", dependencies = c("Depends", "Imports", "LinkingTo"))
'

# Verify the package is actually loadable. If install.packages() silently
# failed (its default behaviour), this check will catch it.
if ! Rscript -e 'library(sumer)' >/dev/null 2>&1; then
    echo "ERROR: sumer is not loadable after install." >&2
    echo "       Re-running install with full dependency output for diagnostics:" >&2
    Rscript -e '
      options(repos = c(CRAN = "https://cloud.r-project.org"))
      install.packages("sumer", dependencies = c("Depends", "Imports", "LinkingTo"))
    ' || true
    if ! Rscript -e 'library(sumer)' >/dev/null 2>&1; then
        echo "ERROR: sumer still not loadable. Aborting build." >&2
        exit 1
    fi
fi

echo "--- sumer package installed ---"
