# build/derivations/lm-studio.nix
# LM Studio: Local AI inference and model management for macOS
{ lib, stdenv, fetchurl, undmg, platforms }:

let
  version = "0.3.10"; # Update to the latest LM Studio version
  # Dynamically select the correct architecture string for the URL
  arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
in
stdenv.mkDerivation rec {
  pname = "lm-studio";
  inherit version;

  src = fetchurl {
    # LM Studio's standard download URL pattern
    url = "https://download.lmstudio.ai/mac/LM-Studio-${version}-mac-${arch}.dmg";
    # Nix will fail on first run and give you the real hash. Replace this placeholder.
    hash = "sha256-BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=";
  };

  nativeBuildInputs = [ undmg ];

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/Applications
    
    # undmg extracts the contents of the DMG into the current directory
    undmg $src
    
    # The extracted app is named "LM Studio.app"
    mv "LM Studio.app" $out/Applications/ || mv *.app $out/Applications/
    
    # Ensure proper macOS permissions
    chmod -R +w $out/Applications/"LM Studio.app"
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Local AI inference and model management, optimized for Apple Silicon and Intel Macs";
    homepage = "https://lmstudio.ai/";
    license = licenses.unfree; # LM Studio is free to use but proprietary
    platforms = platforms.darwin;
    maintainers = [ "9hs6r4bfy5-beep" ];
  };
}
