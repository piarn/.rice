#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"

# dots-greeter (greetd's greeter): the quickshell login in sway, falling
# back to agreety whenever that doesn't end in a started session.
G=$REPO/.bootstrap/dots-greeter
export XDG_RUNTIME_DIR=$TMP/run HOME=$TMP/home
mkdir -p "$XDG_RUNTIME_DIR"
# sway-session stub; GREETER_STUB says how the greeter inside it ended
stub sway-session '
echo "sway-session $* safe=[${SWAY_SESSION_SAFE_CONFIG-unset}]" >>"$CALLS"
case "$GREETER_STUB" in
    launched) echo 0 >"$XDG_RUNTIME_DIR/dots-greeter.status" ;;
    crashed) echo 134 >"$XDG_RUNTIME_DIR/dots-greeter.status" ;;
    sway-died) exit 1 ;;
esac'
stub agreety 'echo "agreety $*" >>"$CALLS"'
export DOTS_SWAY_SESSION=$TMP/stubs/sway-session DOTS_AGREETY=$TMP/stubs/agreety

: >"$CALLS"; GREETER_STUB=launched "$G" 2>/dev/null; rc=$?
check "session started: done" [ "$rc" = 0 ]
check "session started: no text login" not_called "agreety"
check "sway via sway-session with the greeter config" called "sway-session --config /etc/greetd/dots-greeter.sway"
check "no safe-mode desktop for the greetd user" called "safe=[]"

: >"$CALLS"; GREETER_STUB=crashed "$G" 2>/dev/null
check "greeter crashed: text login" called "agreety --cmd /usr/local/bin/sway-session"

: >"$CALLS"; GREETER_STUB=sway-died "$G" 2>/dev/null
check "sway failed: text login" called "agreety"

# a status left by an earlier greeter must not count as this one's
echo 0 >"$XDG_RUNTIME_DIR/dots-greeter.status"
: >"$CALLS"; GREETER_STUB=sway-died "$G" 2>/dev/null
check "stale status ignored" called "agreety"

finish
