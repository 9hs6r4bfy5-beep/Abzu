# build/derivations/davit.nix
# Davit: Quick notes and reminders in the macOS menu bar
{ lib, stdenv, fetchurl, undmg }:

stdenv.mkDerivation rec {
  pname = "davit";
  version = "1.0.0"; # Update to the latest version

  src = fetchurl {
    # Replace with the actual direct download URL for the Davit .dmg
    url = "https://davit.app/download/Davit.dmg"; 
    hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
  };

  nativeBuildInputs = [ undmg ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    
    undmg $src
    find . -maxdepth 2 -name "*.app" -exec mv {} $out/Applications/ \;
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Quick notes and reminders in the macOS menu bar";
    homepage = "https://davit.app/";
    license = licenses.unfree; # Assuming proprietary/free
    platforms = platforms.darwin;
  };
}
