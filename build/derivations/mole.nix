# build/derivations/mole.nix
# Mole: A lightweight macOS system status bar tool
{ lib, stdenv, fetchurl, unzip }:

stdenv.mkDerivation rec {
  pname = "mole";
  version = "1.0.0"; # Update to the latest release version

  src = fetchurl {
    # Check the latest release on https://github.com/tw93/Mole/releases for the exact asset name
    url = "https://github.com/tw93/Mole/releases/download/v${version}/Mole.zip";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    
    unzip -q $src
    find . -maxdepth 2 -name "*.app" -exec mv {} $out/Applications/ \;
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "A lightweight macOS system status bar tool";
    homepage = "https://github.com/tw93/Mole";
    license = licenses.mit;
    platforms = platforms.darwin;
  };
}
