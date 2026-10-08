# build/derivations/iina.nix
# IINA: The modern video player for macOS
{ lib, stdenv, fetchurl, undmg, platforms }:

stdenv.mkDerivation rec {
  pname = "iina";
  version = "1.3.5"; # Update to the latest IINA release

  src = fetchurl {
    url = "https://dl.iina.io/IINA.v${version}.dmg";
    hash = "sha256-CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC=";
  };

  nativeBuildInputs = [ undmg ];

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/Applications
    
    # undmg extracts the contents of the DMG into the current directory
    undmg $src
    
    # Move the extracted .app bundle to the Applications directory
    # (The folder name might vary slightly, e.g., "IINA.app")
    mv *.app $out/Applications/ || mv IINA.app $out/Applications/
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "The modern video player for macOS, based on mpv";
    homepage = "https://iina.io/";
    license = licenses.gpl3;
    platforms = platforms.darwin;
    maintainers = [ "9hs6r4bfy5-beep" ];
  };
}
