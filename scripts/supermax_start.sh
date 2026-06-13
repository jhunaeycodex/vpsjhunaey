#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
LOG_FILE="$WEB_ROOT/logs/supermax.log"
PID_FILE="$WEB_ROOT/logs/supermax.pid"
CMD="./server/run_analysis.sh super-max --bbfs"

cd "$WEB_ROOT"
mkdir -p logs

if pgrep -af "server/analyze.js|run_analysis.sh super-max|supermax_finalize" | grep -v grep >/tmp/supermax_running.txt; then
  echo "ERROR: SuperMax/analyzer process already running:"
  cat /tmp/supermax_running.txt
  exit 1
fi

if [ ! -f data/all_results_from_source_file.json ]; then
  echo "ERROR: missing data/all_results_from_source_file.json" >&2
  exit 1
fi

if [ ! -x server/run_analysis.sh ]; then
  chmod +x server/run_analysis.sh
fi

if [ -f logs/analysis.lock ]; then
  echo "WARNING: logs/analysis.lock exists. If no analyzer process is running, this may be stale."
  echo "Move/remove it manually or run scripts/supermax_prepare.sh first."
  exit 1
fi

echo "Starting SuperMax heavy run..."
echo "web_root=$WEB_ROOT"
echo "log_file=$LOG_FILE"
echo "started_at=$(date -Is)" > "$LOG_FILE"
echo "command=nice -n 10 ionice -c2 -n7 sudo -u www-data $CMD" >> "$LOG_FILE"
echo >> "$LOG_FILE"

nohup nice -n 10 ionice -c2 -n7 sudo -u www-data $CMD >> "$LOG_FILE" 2>&1 &
PID=$!
echo "$PID" > "$PID_FILE"

echo "STARTED pid=$PID"
echo "PID file: $PID_FILE"
echo "Log file: $LOG_FILE"
echo
echo "Use: tail -f $LOG_FILE"
echo "Use: bash /root/vpsjhunaey/scripts/supermax_status.sh"
