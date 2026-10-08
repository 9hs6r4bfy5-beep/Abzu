# build/derivations/intel-sde.nix
# Intel Software Development Emulator: AVX/AVX2 instruction emulation for older Macs
{ lib, stdenv, fetchurl, bzip2, platforms }:

stdenv.mkDerivation rec {
  pname = "intel-sde";
  version = "9.29.0"; # Update to the latest Intel SDE version

  src = fetchurl {
    # Example URL structure for Intel SDE macOS releases
    url = "https://downloadmirror.intel.com/831888/sde-external-${version}-2024-08-29-mac.tar.bz2";
    hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
  };

  nativeBuildInputs = [ bzip2 ];

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    
    # Extract the tarball
    tar -xjf $src
    
    # Find the extracted directory (it usually has a name like sde-external-9.29.0-2024-08-29-mac)
    SDE_DIR=$(find . -maxdepth 1 -type d -name "sde-external-*" | head -n 1)
    
    # Copy the core binaries to the output bin directory
    cp "$SDE_DIR/sde" "$out/bin/"
    cp "$SDE_DIR/sde64" "$out/bin/"
    
    # Make them executable
    chmod +x $out/bin/sde $out/bin/sde64
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Intel Software Development Emulator for executing x86/x86-64 instructions on unsupported hardware";
    homepage = "https://www.intel.com/content/www/us/en/developer/articles/tool/software-development-emulator.html";
    license = licenses.unfree; # Intel's license is proprietary
    platforms = platforms.darwin;
    maintainers = [ "9hs6r4bfy5-beep" ];
  };
}
