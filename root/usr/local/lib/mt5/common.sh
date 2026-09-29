# Shared environment and helpers for the mt5-* scripts. Source it, don't run it.
# WINEPREFIX, WINEDEBUG and WINEDLLOVERRIDES come from the image environment.
# shellcheck shell=bash

export HOME="/config"
export DISPLAY="${DISPLAY:-:1}"
# Selkies preloads 64-bit interposer libraries that 32-bit Wine processes
# can't load.
unset LD_PRELOAD

MT5_DIR="$WINEPREFIX/drive_c/Program Files/MetaTrader 5"
MT5_EXE="$MT5_DIR/terminal64.exe"
# Held by mt5-install for its whole run.
MT5_INSTALL_LOCK="/tmp/mt5-install.lock"

mt5_log() {
    echo "[$(basename "$0")] $(date '+%F %T') $*"
}

# Send this script's output to a log file under /config, keeping the previous
# run's log as FILE.1.
mt5_log_to() {
    [ -f "$1" ] && mv -f "$1" "$1.1"
    exec >"$1" 2>&1
}

# Usage: mt5_lock FILE [flock options]
# Re-runs the calling script while holding FILE. flock -o holds the lock
# itself, so children (sleep, wine) never inherit it and it is released
# exactly when the script exits, however it exits.
mt5_lock() {
    [ "$MT5_LOCK_HELD" = "$1" ] && return
    MT5_LOCK_HELD="$1" exec flock -o "${@:2}" "$1" "$0"
}

mt5_running() {
    pgrep -f 'terminal64\.exe' >/dev/null
}

mt5_start() {
    # MT5_CMD_OPTIONS is word-split on purpose.
    # shellcheck disable=SC2086
    nohup wine "$MT5_EXE" $MT5_CMD_OPTIONS >/dev/null 2>&1 &
}
