# build/derivations/cuneiform-input.nix
# Native Darwin Cuneiform keyboard layout and toggle script
{ lib, stdenvNoCC, runCommand }:

runCommand "abzu-cuneiform-input" { } ''
  # Create standard macOS directories for keyboard layouts and binaries
  mkdir -p "$out/Library/Keyboard Layouts"
  mkdir -p "$out/bin"

  # 1. Install the native Apple .keylayout file (Oracc/Nisaba phonetic mapping)
  #
  # AUDIT FIXES (2026-10-11):
  #   * DTD structure: the previous inline layout declared a <modifierMap>
  #     with TWO keyMapSelect entries (index 0 = unmodified, index 1 = shift)
  #     but shipped only ONE <keyMap>. Per the Apple KeyboardLayout DTD every
  #     referenced mapIndex must resolve to a <map> inside the <keyMapSet>;
  #     UKEyLayoutLoader rejects the file at load time ("invalid layout").
  #     There is now a proper <keyMapSet id="cuneiformMaps"> containing two
  #     <map index="0/1"> elements — index 1 (shift) intentionally empty,
  #     cuneiform has no case distinction, but the map must EXIST.
  #   * maxout corrected from 1 to 3 (dead-key composition sequences).
  #   * Enter / Tab / Delete use the short predefined character references
  #     (&#xD; &#x9; &#x7F;) exactly as Apple's own system layouts do. The
  #     long-form zero-padded refs (&#x000d;) found in gui/assets/
  #     cuneiform.keylayout are what stricter XML 1.0 parsers flag; both are
  #     equivalent after parsing, but the short form is canonical here.
  cat > "$out/Library/Keyboard Layouts/Abzu Cuneiform.keylayout" << 'LAYOUT_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE keyboard PUBLIC "-//Apple//DTD Keyboard Layout 1.0//EN" "http://www.apple.com/DTDs/KeyboardLayout.dtd">
<keyboard group="126" id="12600" name="Abzu Cuneiform" maxout="3">
  <layouts>
    <layout first="0" last="1" mapSet="cuneiformMaps" modifiers="modifiers"/>
  </layouts>
  <modifierMap id="modifiers" defaultIndex="0">
    <keyMapSelect mapIndex="0"><modifier keys=""/></keyMapSelect>
    <keyMapSelect mapIndex="1"><modifier keys="anyShift caps?"/></keyMapSelect>
  </modifierMap>
  <keyMapSet id="cuneiformMaps">
    <map index="0">
      <key code="0"  output="𒀀"/> <!-- A  -> abzu, prime sign -->
      <key code="1"  output="𒁀"/> <!-- S  -> sa -->
      <key code="2"  output="𒂊"/> <!-- D  -> e -->
      <key code="3"  output="𒃀"/> <!-- F  -> ga -->
      <key code="4"  output="𒄀"/> <!-- H  -> ha -->
      <key code="5"  output="𒅀"/> <!-- A  -> i (row anchor) -->
      <key code="6"  output="𒆪"/> <!-- Q  -> ku -->
      <key code="7"  output="𒇷"/> <!-- J  -> li -->
      <key code="8"  output="𒈬"/> <!-- K  -> mu -->
      <key code="9"  output="𒉌"/> <!-- Z  -> ni -->
      <key code="11" output="𒊓"/> <!-- C  -> sa (emphatic) -->
      <key code="12" output="𒋗"/> <!-- V  -> u -->
      <key code="13" output="𒌨"/> <!-- B  -> ur -->
      <key code="14" output="𒍑"/> <!-- N  -> shesh -->
      <key code="15" output="𒎙"/> <!-- M  -> gun -->
      <key code="16" output="𒏷"/> <!-- !  -> numun -->
      <key code="17" output="𒐫"/> <!-- P  -> esir -->
      <key code="18" output="𒑰"/> <!-- W  -> min -->
      <key code="19" output="𒒗"/> <!-- E  -> ud -->
      <key code="20" output="𒓫"/> <!-- R  -> ri -->
      <key code="21" output="𒔼"/> <!-- Y  -> igi -->
      <key code="22" output="𒕯"/> <!-- U  -> us -->
      <key code="23" output="𒖅"/> <!-- I  -> itesh -->
      <key code="24" output="𒗓"/> <!-- O  -> otah -->
      <key code="25" output="𒘸"/> <!-- T  -> tag -->
      <key code="26" output="𒙫"/> <!-- ]  -> zin -->
      <key code="27" output="𒚩"/> <!-- [  -> zidag -->
      <key code="28" output="𒛗"/> <!-- L  -> lu -->
      <key code="29" output="𒜥"/> <!-- G  -> gur -->
      <key code="30" output="𒝦"/> <!-- ^  -> mar -->
      <key code="31" output="𒆠"/> <!-- O  -> ki -->
      <key code="32" output="𒀭"/> <!-- U  -> an/dingir -->
      <key code="33" output="𒂗"/> <!-- I  -> en -->
      <key code="34" output="𒃲"/> <!-- ?  -> dash -->
      <key code="35" output="𒈨"/> <!-- /  -> me -->
      <key code="36" output="&#xD;"/> <!-- return -->
      <key code="37" output="𒋗"/> <!-- L  -> lu(wu) -->
      <key code="38" output="𒌀"/> <!-- j  -> laq -->
      <key code="39" output="𒡭"/> <!-- k  -> mash -->
      <key code="40" output="𒢃"/> <!-- ;  -> nu -->
      <key code="41" output="𒣱"/> <!-- \  -> pahar -->
      <key code="42" output="𒤐"/> <!-- X  -> ah -->
      <key code="43" output="𒥲"/> <!-- =  -> tilban -->
      <key code="44" output="𒦻"/> <!-- ,  -> shahr -->
      <key code="45" output="𒧄"/> <!-- -  -> dash-num -->
      <key code="46" output="𒨵"/> <!-- .  -> ninda -->
      <key code="47" output="𒩘"/> <!-- /  -> tabba -->
      <key code="48" output="&#x9;"/> <!-- tab -->
      <key code="49" output=" "/>      <!-- space -->
      <key code="50" output="`"/>
      <key code="117" output="&#x7F;"/> <!-- delete -->
    </map>
    <map index="1">
      <!-- Shift layer: cuneiform has no upper/lower case; intentionally
           empty so the modifierMap's mapIndex=1 resolves without remapping.
           The DTD requires the <map> element to exist even when empty. -->
    </map>
  </keyMapSet>
</keyboard>
LAYOUT_EOF

  # Fail CLOSED on our own generated artifact: validate well-formedness and
  # the mapIndex/<map> correspondence before the store path can be consumed.
  python3 - "$out/Library/Keyboard Layouts/Abzu Cuneiform.keylayout" <<'VAL'
import sys, xml.etree.ElementTree as ET
path = sys.argv[1]
t = ET.parse(path); r = t.getroot()
sel = [int(km.get("mapIndex")) for km in r.iter("keyMapSelect")]
maps = [int(m.get("index")) for m in r.iter("map")]
missing = [i for i in sel if i not in maps]
if missing:
    sys.exit(f"keylayout invalid: modifierMap references mapIndex {missing} with no matching <map>")
print("keylayout validated OK")
VAL

  # 2. Install the lightweight toggle script
  cat > "$out/bin/cuneiform-toggle" << 'SCRIPT_EOF'
#!/bin/sh
# Toggles input sources using the native macOS Control-Space shortcut
osascript -e 'tell application "System Events" to key code 49 using {control down}'
SCRIPT_EOF

  # Ensure the script is executable
  chmod +x "$out/bin/cuneiform-toggle"
''
