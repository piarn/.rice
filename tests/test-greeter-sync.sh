#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

# greeter-sync: the login screen's copy of the shell, theme and input/outputs
export DOTS_GREETER_DIR=$TMP/greeter RICE_DIR=$TMP/rice DOTS_SWAY_CONFIG=$TMP/sway.conf
mkdir -p "$RICE_DIR/desktop/quickshell/.config/quickshell/components" "$RICE_DIR/quickshell" "$RICE_DIR/sway"
echo shell >"$RICE_DIR/desktop/quickshell/.config/quickshell/greeter.qml"
echo comp >"$RICE_DIR/desktop/quickshell/.config/quickshell/components/A.qml"
echo red >"$RICE_DIR/quickshell/Colors.qml"; echo mod >"$RICE_DIR/quickshell/qmldir"
echo "output eDP-1 scale 1" >"$RICE_DIR/sway/outputs.conf"
printf 'set $mod Mod4\ninput "type:keyboard" {\n    xkb_layout "lt"\n}\nbindsym x exec y\n' >"$DOTS_SWAY_CONFIG"

"$BIN/greeter-sync"
check "not set up yet: quietly nothing" [ ! -e "$DOTS_GREETER_DIR" ]

mkdir "$DOTS_GREETER_DIR"
"$BIN/greeter-sync"
check "shell copied" [ "$(cat "$DOTS_GREETER_DIR/shell/components/A.qml")" = comp ]
check "theme copied" [ "$(cat "$DOTS_GREETER_DIR/rice/quickshell/Colors.qml")" = red ]
check "outputs copied" grep -q eDP-1 "$DOTS_GREETER_DIR/sway.d/outputs.conf"
check "keyboard block only" [ "$(grep -c . "$DOTS_GREETER_DIR/sway.d/input.conf")" = 3 ]
check "readable by the greetd user" [ "$(stat -c %a "$DOTS_GREETER_DIR/shell/greeter.qml")" = 644 ]
check "--check: current" "$BIN/greeter-sync" --check

echo blue >"$RICE_DIR/quickshell/Colors.qml"
check "--check: theme changed" not "$BIN/greeter-sync" --check
rm "$RICE_DIR/desktop/quickshell/.config/quickshell/components/A.qml"
"$BIN/greeter-sync"
check "resync: removed files go" [ ! -e "$DOTS_GREETER_DIR/shell/components/A.qml" ]
check "resync: no staging left" [ -z "$(find "$DOTS_GREETER_DIR" -maxdepth 1 -name '.*')" ]

finish
