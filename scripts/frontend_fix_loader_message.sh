#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
LOADER="$WEB_ROOT/assets/js/data-loader.js"
BACKUP_DIR="$WEB_ROOT/backups/frontend"
TS="$(date +%Y%m%d_%H%M%S)"

if [ ! -f "$LOADER" ]; then
  echo "ERROR: missing $LOADER" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
cp "$LOADER" "$BACKUP_DIR/data-loader.js.$TS.bak"

echo "Backup: $BACKUP_DIR/data-loader.js.$TS.bak"

python3 - <<'PY'
from pathlib import Path
path = Path('/var/www/html/prediksi/assets/js/data-loader.js')
text = path.read_text(encoding='utf-8')
old = "Jalankan analyzer di VPS: <code>cd /var/www/html/prediksi && ./server/run_analysis.sh super-max --bbfs</code>. Pastikan file input ada di <code>data/all_results_from_source_file.json</code>."
new = "Output JSON generated belum tersedia. Jalankan analyzer di VPS melalui server-side script, lalu muat ulang dashboard."
if old not in text:
    # Fallback: remove only raw-data mention if surrounding text changed.
    text2 = text.replace(" Pastikan file input ada di <code>data/all_results_from_source_file.json</code>.", "")
    if text2 == text:
        print("No matching raw-data frontend message found; no change made.")
    else:
        path.write_text(text2, encoding='utf-8')
        print("Removed raw-data reference from frontend error message.")
else:
    path.write_text(text.replace(old, new), encoding='utf-8')
    print("Replaced frontend error message.")
PY

chown www-data:www-data "$LOADER"
chmod 644 "$LOADER"

if grep -q 'all_results_from_source_file.json' "$LOADER"; then
  echo "FIX_STATUS=NEEDS_REVIEW"
  grep -n 'all_results_from_source_file.json' "$LOADER" || true
  exit 1
fi

echo "FIX_STATUS=OK"
