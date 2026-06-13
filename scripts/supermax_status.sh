#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
LOG_FILE="$WEB_ROOT/logs/supermax.log"
PID_FILE="$WEB_ROOT/logs/supermax.pid"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
mkdir -p "$REPORT_DIR"
STATUS_FILE="$REPORT_DIR/supermax_status_latest.txt"

{
  echo "SUPERMAX STATUS"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo
  echo "== PROCESS =="
  ps aux | grep -E 'server/analyze.js|run_analysis.sh super-max|supermax_finalize|node' | grep -v grep || true
  echo
  echo "== PID FILE =="
  if [ -f "$PID_FILE" ]; then
    echo "$(cat "$PID_FILE")"
  else
    echo "missing"
  fi
  echo
  echo "== MEMORY =="
  free -h
  echo
  echo "== DISK =="
  df -h / "$WEB_ROOT" 2>/dev/null || df -h
  echo
  echo "== LOG TAIL =="
  if [ -f "$LOG_FILE" ]; then
    tail -80 "$LOG_FILE"
  else
    echo "missing $LOG_FILE"
  fi
  echo
  echo "== GENERATED FILE TIMES =="
  ls -lah "$WEB_ROOT/data/generated" 2>/dev/null | tail -40 || true
  echo
  echo "== AUDIT HEAD =="
  head -80 "$WEB_ROOT/data/generated/latest_prediction_run_audit.json" 2>/dev/null || true
} | tee "$STATUS_FILE"

echo
echo "Status saved: $STATUS_FILE"
