# build/derivations/tor-browser.nix
# Fetcher for Tor Browser: System-agnostic (Intel/ARM) privacy browser
{ lib, stdenv, fetchurl, undmg }:

let
  version = "13.5.3";
  # Dynamically select the correct architecture string for the Tor Project URL
  arch = if stdenv.hostPlatform.isAarch64 then "macos_aarch64" else "osx64";
in
stdenv.mkDerivation rec {
  pname = "tor-browser";
  inherit version;

  src = fetchurl {
    url = "https://dist.torproject.org/torbrowser/${version}/TorBrowser-${version}-${arch}_en-US.dmg";
    # Nix will fail on first run and give you the real hash. Replace this placeholder.
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  nativeBuildInputs = [ undmg ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    
    # undmg extracts the DMG contents into the current directory
    undmg $src
    
    # Robustly find and move the .app bundle, regardless of slight naming variations
    find . -maxdepth 2 -name "*.app" -exec mv {} $out/Applications/ \;
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Privacy-focused web browser with built-in Tor network routing";
    homepage = "https://www.torproject.org/";
    license = licenses.mpl20;
    platforms = platforms.darwin;
  };
}
