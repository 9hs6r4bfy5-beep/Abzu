# build/derivations/lm-studio.nix
# Fetcher for LM Studio: System-agnostic (Intel/ARM) local AI inference
{ lib, stdenv, fetchurl, undmg }:

let
  version = "0.3.10";
  # Dynamically select the correct architecture string for LM Studio URL
  arch = if stdenv.hostPlatform.isAarch64 then "arm64" else "x64";
in
stdenv.mkDerivation rec {
  pname = "lm-studio";
  inherit version;

  src = fetchurl {
    # CORRECTED URL
    url = "https://download.lmstudio.ai/mac/LM-Studio-${version}-mac-${arch}.dmg";
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
    description = "Local AI inference and model management, optimized for Apple Silicon and Intel Macs";
    homepage = "https://lmstudio.ai/";
    license = licenses.unfree;
    platforms = platforms.darwin;
  };
}
