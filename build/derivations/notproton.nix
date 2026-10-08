# build/derivations/notproton.nix
# NotProton: Enables Steam Play (Proton) functionality in the native macOS Steam client
{ lib, stdenv, fetchurl, unzip, platforms }:

stdenv.mkDerivation rec {
  pname = "notproton";
  version = "1.0.3"; # Update to the latest release version

  src = fetchurl {
    # Check the latest release on https://github.com/NotProtonNot/NotProton/releases for the exact asset name
    # It is typically a .zip or .dmg containing the NotProton.app and supporting files
    url = "https://github.com/NotProtonNot/NotProton/releases/download/${version}/NotProton-${version}.zip";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    runHook preInstall
    
    # Create standard macOS application and support directories
    mkdir -p $out/Applications
    mkdir -p $out/Library/Application\ Support/NotProton
    
    # Extract the release archive
    unzip -q $src
    
    # Move the main application bundle
    find . -maxdepth 2 -name "NotProton.app" -exec mv {} $out/Applications/ \;
    
    # Move supporting runners/dylibs if they are packaged separately
    # (Adjust this based on the actual contents of the release zip)
    if [ -d "runners" ]; then
      cp -r runners $out/Library/Application\ Support/NotProton/
    fi
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Enables Steam Play functionality from Linux Steam in the native macOS Steam client";
    homepage = "https://github.com/NotProtonNot/NotProton";
    license = licenses.gpl3; # Based on repo licenses
    platforms = platforms.darwin;
    maintainers = [ "9hs6r4bfy5-beep" ];
  };
}
