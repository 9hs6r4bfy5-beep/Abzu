# build/derivations/cuneiform-input.nix
# Native Darwin Cuneiform keyboard layout and toggle script
{ lib, stdenvNoCC, runCommand }:

runCommand "abzu-cuneiform-input" { } ''
  # Create standard macOS directories for keyboard layouts and binaries
  mkdir -p "$out/Library/Keyboard Layouts"
  mkdir -p "$out/bin"

  # 1. Install the native Apple .keylayout file (Oracc/Nisaba phonetic mapping)
  cat > "$out/Library/Keyboard Layouts/Abzu Cuneiform.keylayout" << 'LAYOUT_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE keyboard PUBLIC "-//Apple//DTD Keyboard Layout 1.0//EN" "http://www.apple.com/DTDs/KeyboardLayout.dtd">
<keyboard group="126" id="12600" name="Abzu Cuneiform" maxout="1">
  <layouts>
    <layout first="0" last="1" mapSet="map" modifiers="modifiers"/>
  </layouts>
  <modifierMap id="modifiers" defaultIndex="7">
    <keyMapSelect mapIndex="0"><modifier keys=""/></keyMapSelect>
    <keyMapSelect mapIndex="1"><modifier keys="shift"/></keyMapSelect>
  </modifierMap>
  <keyMap id="map">
    <key code="0" output="𒀀"/> <key code="1" output="𒁁"/> <key code="2" output="𒂵"/>
    <key code="3" output="𒃻"/> <key code="4" output="𒄀"/> <key code="5" output="𒅅"/>
    <key code="6" output="𒆳"/> <key code="7" output="𒇽"/> <key code="8" output="𒈝"/>
    <key code="9" output="𒉡"/> <key code="11" output="𒊕"/> <key code="12" output="𒋗"/>
    <key code="13" output="𒌨"/> <key code="14" output="𒍑"/> <key code="15" output="𒎙"/>
    <key code="16" output="𒏑"/> <key code="17" output="𒐫"/> <key code="18" output="𒑰"/>
    <key code="19" output="𒒗"/> <key code="20" output="𒓫"/> <key code="31" output="𒆠"/>
    <key code="32" output="𒀭"/> <key code="33" output="𒂗"/> <key code="34" output="𒃲"/>
    <key code="35" output="𒈬"/> <key code="36" output="𒀀"/> <key code="37" output="𒋗"/>
  </keyMap>
</keyboard>
LAYOUT_EOF

  # 2. Install the lightweight toggle script
  cat > "$out/bin/cuneiform-toggle" << 'SCRIPT_EOF'
#!/bin/sh
# Toggles input sources using the native macOS Control-Space shortcut
osascript -e 'tell application "System Events" to key code 49 using {control down}'
SCRIPT_EOF

  # Ensure the script is executable
  chmod +x "$out/bin/cuneiform-toggle"
''
