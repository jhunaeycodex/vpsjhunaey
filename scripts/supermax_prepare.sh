#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
SWAP_FILE="${SWAP_FILE:-/swapfile}"
SWAP_SIZE="${SWAP_SIZE:-2G}"

cd "$WEB_ROOT"

echo "=== SUPERMAX PREPARE ==="
date -Is

echo
echo "[1/8] Check required files"
required=(
  "index.html"
  "data/all_results_from_source_file.json"
  "data/generated/manifest.json"
  "data/generated/markets.json"
  "server/analyze.js"
  "server/run_analysis.sh"
  "server/supermax_finalize.js"
)
for f in "${required[@]}"; do
  if [ ! -e "$f" ]; then
    echo "ERROR: missing $WEB_ROOT/$f" >&2
    exit 1
  fi
  echo "OK: $f"
done

echo
echo "[2/8] Check Node"
node -v
npm -v || true

echo
echo "[3/8] Check current memory"
free -h

echo
echo "[4/8] Ensure swap exists"
if swapon --show | grep -q .; then
  echo "Swap already active:"
  swapon --show
else
  echo "No swap active. Creating $SWAP_FILE size $SWAP_SIZE ..."
  if [ ! -f "$SWAP_FILE" ]; then
    fallocate -l "$SWAP_SIZE" "$SWAP_FILE" || dd if=/dev/zero of="$SWAP_FILE" bs=1M count=2048 status=progress
  fi
  chmod 600 "$SWAP_FILE"
  mkswap "$SWAP_FILE"
  swapon "$SWAP_FILE"
  if ! grep -q "^$SWAP_FILE " /etc/fstab; then
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
  fi
  echo "Swap activated:"
  swapon --show
fi

echo
echo "[5/8] Ensure permissions"
chown -R www-data:www-data "$WEB_ROOT"
find "$WEB_ROOT" -type d -exec chmod 755 {} \;
find "$WEB_ROOT" -type f -exec chmod 644 {} \;
chmod +x "$WEB_ROOT/server/run_analysis.sh" || true
chmod +x "$WEB_ROOT/server/run_supermax_bbfs.sh" || true

echo
echo "[6/8] Create backup of current generated output"
mkdir -p "$WEB_ROOT/backups/generated"
backup_name="generated_$(date +%Y%m%d_%H%M%S).tar.gz"
tar -czf "$WEB_ROOT/backups/generated/$backup_name" -C "$WEB_ROOT/data" generated
ls -lh "$WEB_ROOT/backups/generated/$backup_name"

echo
echo "[7/8] Check stale analysis lock"
if pgrep -af "server/analyze.js|run_analysis.sh|supermax" | grep -v grep >/tmp/supermax_process_check.txt; then
  echo "Analysis-related process found:"
  cat /tmp/supermax_process_check.txt
  echo "Do not start a new run until this is reviewed."
else
  echo "No analysis process running."
  if [ -f "$WEB_ROOT/logs/analysis.lock" ]; then
    echo "Stale lock candidate exists: $WEB_ROOT/logs/analysis.lock"
    echo "Moving it to logs/analysis.lock.stale.$(date +%Y%m%d_%H%M%S)"
    mv "$WEB_ROOT/logs/analysis.lock" "$WEB_ROOT/logs/analysis.lock.stale.$(date +%Y%m%d_%H%M%S)"
  fi
fi

echo
echo "[8/8] Final lightweight web check"
curl -k -I --max-time 10 https://jhunaey.my.id/ || true
curl -k -I --max-time 10 https://jhunaey.my.id/data/generated/manifest.json || true
curl -k -I --max-time 10 https://jhunaey.my.id/server/ || true

echo
echo "PREPARE_STATUS=OK"
echo "Next, run scripts/supermax_start.sh only when you intentionally want to start the heavy SuperMax run."
