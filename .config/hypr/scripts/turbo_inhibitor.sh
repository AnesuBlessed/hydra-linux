#!/usr/bin/env bash
# Hydra Linux - Turbo Mode Screen & Sleep Inhibitor
# Inhibits idle, system suspend, and lid-switch sleep when in Turbo (performance) mode.

RUNDIR="${XDG_RUNTIME_DIR:-/run/user/$UID}/quickshell"
mkdir -p "$RUNDIR"
PIDFILE="$RUNDIR/turbo_inhibitor.pid"

stop_inhibitor() {
    if [ -f "$PIDFILE" ]; then
        PID=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
    pkill -f "systemd-inhibit.*Hydra Turbo" 2>/dev/null || true
}

start_inhibitor() {
    stop_inhibitor
    nohup systemd-inhibit --what=idle:sleep:handle-lid-switch \
                          --who="Hydra Turbo Mode" \
                          --why="High performance active - preventing screen close and sleep" \
                          sleep infinity </dev/null >/dev/null 2>&1 &
    PID=$!
    disown "$PID" 2>/dev/null || true
    echo "$PID" > "$PIDFILE"
}

PROFILE=$(powerprofilesctl get 2>/dev/null || echo "balanced")

case "$1" in
    start)
        start_inhibitor
        ;;
    stop)
        stop_inhibitor
        ;;
    sync|*)
        if [ "$PROFILE" = "performance" ]; then
            if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
                exit 0
            else
                start_inhibitor
            fi
        else
            stop_inhibitor
        fi
        ;;
esac
