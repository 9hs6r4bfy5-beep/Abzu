# build/derivations/tor-browser.nix
# Tor Browser: Privacy-focused web browser with built-in Tor network routing
{ lib, stdenv, fetchurl, undmg, platforms }:

let
  version = "13.5.3"; # Update to the latest stable Tor Browser version
  # Dynamically select the correct architecture string for the URL
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
    
    # undmg extracts the contents of the DMG into the current directory
    undmg $src
    
    # The extracted app is typically named "Tor Browser.app"
    # We use a wildcard or specific name to ensure it moves correctly
    mv "Tor Browser.app" $out/Applications/ || mv *.app $out/Applications/
    
    # Ensure proper macOS permissions
    chmod -R +w $out/Applications/"Tor Browser.app"
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "Privacy-focused web browser with built-in Tor network routing";
    homepage = "https://www.torproject.org/";
    license = licenses.mpl20;
    platforms = platforms.darwin;
    maintainers = [ "9hs6r4bfy5-beep" ];
  };
}
