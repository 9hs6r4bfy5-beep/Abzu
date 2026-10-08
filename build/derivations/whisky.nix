# build/derivations/whisky.nix
# Frankea's Whisky: A modern Wine/GPTK wrapper for macOS gaming
{ lib, stdenv, fetchurl, unzip, platforms }:

stdenv.mkDerivation rec {
  pname = "whisky";
  version = "4.5.105-beta.1"; # Update this to the latest frankea/Whisky release

  src = fetchurl {
    # Frankea's releases typically provide a Whisky.zip asset
    url = "https://github.com/frankea/Whisky/releases/download/v${version}/Whisky.zip";
    # Nix will fail on first run and give you the real hash. Replace this placeholder.
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ unzip ];

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/Applications
    # Extract the .app bundle directly into the Applications directory
    unzip -q $src -d $out/Applications
    
    # Ensure the app bundle has correct macOS permissions
    chmod -R +w $out/Applications/Whisky.app
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "A modern Wine wrapper for macOS built to play Windows games (Frankea community fork)";
    homepage = "https://frankea.github.io/Whisky/";
    license = licenses.gpl3;
    platforms = platforms.darwin;
    maintainers = [ "9hs6r4bfy5-beep" ];
  };
}
