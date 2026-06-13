#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
PID_FILE="$WEB_ROOT/logs/supermax.pid"
LOG_FILE="$WEB_ROOT/logs/supermax.log"

echo "Stopping SuperMax/analyzer processes if running..."

if [ -f "$PID_FILE" ]; then
  PID="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    echo "Sending TERM to pid=$PID"
    kill "$PID" 2>/dev/null || true
    sleep 3
  fi
fi

pkill -TERM -f "server/analyze.js" 2>/dev/null || true
pkill -TERM -f "run_analysis.sh super-max" 2>/dev/null || true
pkill -TERM -f "supermax_finalize" 2>/dev/null || true
sleep 3

if pgrep -af "server/analyze.js|run_analysis.sh super-max|supermax_finalize" | grep -v grep; then
  echo "Some processes remain. Sending KILL..."
  pkill -KILL -f "server/analyze.js" 2>/dev/null || true
  pkill -KILL -f "run_analysis.sh super-max" 2>/dev/null || true
  pkill -KILL -f "supermax_finalize" 2>/dev/null || true
fi

if [ -f "$PID_FILE" ]; then
  mv "$PID_FILE" "$PID_FILE.stopped.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || rm -f "$PID_FILE"
fi

echo "STOP_STATUS=DONE"
echo "Recent log:"
if [ -f "$LOG_FILE" ]; then
  tail -40 "$LOG_FILE"
fi
