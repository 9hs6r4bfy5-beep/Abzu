#!/bin/sh
# cuneiform-toggle: Toggles between the default input source and Abzu Cuneiform
# This script simulates the default macOS shortcut for switching input sources (Control-Space).
# Users should ensure "Select next input source" is set to ^Space in System Settings > Keyboard > Keyboard Shortcuts.

osascript -e 'tell application "System Events" to key code 49 using {control down}'
