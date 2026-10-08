# build/derivations/antinote.nix
# Antinote: Minimal, distraction-free note-taking for macOS
{ lib, stdenv, fetchurl, undmg }:

stdenv.mkDerivation rec {
  pname = "antinote";
  version = "1.0.0"; # Update to the latest version

  src = fetchurl {
    # Replace with the actual direct download URL for the Antinote .dmg or .zip
    url = "https://antinote.io/download/Antinote.dmg";
    hash = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
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
    description = "Minimal, distraction-free note-taking for macOS";
    homepage = "https://antinote.io/";
    license = licenses.unfree; # Assuming proprietary/free
    platforms = platforms.darwin;
  };
}
