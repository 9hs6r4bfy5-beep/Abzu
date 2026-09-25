#!/usr/bin/env bash
set -euo pipefail

# --- Memory constraints for the Rust/Tauri release build -----------------
# The Hotline Tauri crate links OpenSSL, aws-lc, ring, libsodium, tokio,
# reqwest, tauri and rustls into a single crate. LLVM's optimizer on that
# crate exceeds the runner's container memory limit even at opt-level=1,
# aborting with "rustc-LLVM ERROR: out of memory". The following pushes
# memory usage to the absolute minimum.
export CARGO_BUILD_JOBS=1
export CARGO_PROFILE_RELEASE_LTO=false
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=256
export CARGO_PROFILE_RELEASE_OPT_LEVEL=0
export CARGO_PROFILE_RELEASE_DEBUG=0
export CARGO_PROFILE_RELEASE_DEBUG_ASSERTIONS=false
export CARGO_PROFILE_RELEASE_OVERFLOW_CHECKS=false
export CARGO_PROFILE_RELEASE_INCREMENTAL=false
export CARGO_PROFILE_RELEASE_PANIC=abort
export CARGO_PROFILE_RELEASE_STRIP=symbols
export NODE_OPTIONS=--max-old-space-size=2048
# Tell the linker to re-read object files instead of keeping them all
# in memory. Slower link, much lower peak RSS.
export RUSTFLAGS="-C debuginfo=0 -C link-arg=-Wl,--no-keep-memory"
# -------------------------------------------------------------------------

echo "--- Building Hotline Navigator ---"

# Clone the repository
git clone --depth 1 https://github.com/fuzzywalrus/hotline.git /tmp/hotline

# Build the Tauri application
cd /tmp/hotline/hotline-tauri

# Install Node.js dependencies
npm install

# Build the production bundle for Linux x86_64
npm run build:linux

# The `--target x86_64-unknown-linux-gnu` flag causes Cargo to place the
# binary under target/x86_64-unknown-linux-gnu/release/, not target/release/.
BIN_SRC=""
for candidate in \
    "src-tauri/target/x86_64-unknown-linux-gnu/release/hotline-tauri" \
    "src-tauri/target/release/hotline-tauri"
do
    if [ -f "$candidate" ]; then
        BIN_SRC="$candidate"
        break
    fi
done

if [ -n "$BIN_SRC" ]; then
    cp "$BIN_SRC" /usr/local/bin/hotline-navigator
    chmod +x /usr/local/bin/hotline-navigator
    echo "Hotline Navigator installed to /usr/local/bin/hotline-navigator (from $BIN_SRC)"
else
    echo "Build failed: binary not found in either expected location"
    echo "Contents of src-tauri/target/ (for debugging):"
    ls -R src-tauri/target/ || true
    exit 1
fi

# Create a desktop entry
mkdir -p /usr/share/applications
cat > /usr/share/applications/hotline-navigator.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Hotline Navigator
Comment=A modern Hotline client
Exec=/usr/local/bin/hotline-navigator
Icon=internet-web-browser
Terminal=false
Categories=Network;Chat;
EOF

# Cleanup
cd /
rm -rf /tmp/hotline

echo "--- Hotline Navigator build complete ---"
