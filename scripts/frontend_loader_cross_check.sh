#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
DOMAIN="${DOMAIN:-jhunaey.my.id}"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/frontend_loader_cross_check_latest.txt"
mkdir -p "$REPORT_DIR"

pass=0
fail=0
warn=0
pass_msg(){ pass=$((pass+1)); echo "PASS | $1" | tee -a "$REPORT"; }
fail_msg(){ fail=$((fail+1)); echo "FAIL | $1" | tee -a "$REPORT"; }
warn_msg(){ warn=$((warn+1)); echo "WARN | $1" | tee -a "$REPORT"; }

http_code(){ curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null || true; }

{
  echo "FRONTEND LOADER CROSS CHECK"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo "domain=$DOMAIN"
  echo
} > "$REPORT"

INDEX="$WEB_ROOT/index.html"
LOADER="$WEB_ROOT/assets/js/data-loader.js"

[ -f "$INDEX" ] && pass_msg "index.html ada" || fail_msg "index.html tidak ada"
[ -f "$LOADER" ] && pass_msg "assets/js/data-loader.js ada" || fail_msg "assets/js/data-loader.js tidak ada"

if [ -f "$INDEX" ] && grep -q 'assets/js/data-loader.js' "$INDEX"; then
  pass_msg "index.html memuat loader lokal assets/js/data-loader.js"
else
  fail_msg "index.html tidak memuat loader lokal assets/js/data-loader.js"
fi

if [ -f "$LOADER" ]; then
  echo >> "$REPORT"
  echo "== loader references ==" >> "$REPORT"
  grep -nEi 'fetch\(|data/generated|manifest\.json|markets\.json|latest_|all_results_from_source_file|https?://|localStorage|XMLHttpRequest|axios' "$LOADER" >> "$REPORT" 2>/dev/null || true

  if grep -q 'data/generated' "$LOADER" || grep -q 'manifest.json' "$LOADER" || grep -q 'markets.json' "$LOADER"; then
    pass_msg "loader membaca JSON generated/lokal"
  else
    fail_msg "loader tidak terlihat membaca JSON generated/lokal"
  fi

  if grep -q 'all_results_from_source_file.json' "$LOADER"; then
    fail_msg "loader menyebut data mentah all_results_from_source_file.json"
  else
    pass_msg "loader tidak menyebut data mentah"
  fi

  if grep -nE 'https?://|//cdn|cdnjs|unpkg|jsdelivr|googleapis|gstatic|analytics|gtag|facebook|doubleclick' "$LOADER" >> "$REPORT" 2>/dev/null; then
    fail_msg "loader memiliki referensi eksternal eksplisit"
  else
    pass_msg "loader tidak memiliki referensi eksternal eksplisit"
  fi

  if grep -q 'localStorage' "$LOADER"; then
    warn_msg "loader memakai localStorage; cek apakah bukan data sensitif"
  else
    pass_msg "loader tidak memakai localStorage"
  fi
fi

for p in \
  /data/generated/manifest.json \
  /data/generated/markets.json \
  /data/generated/latest_bbfs_7digit.json \
  /data/generated/latest_bbfs_2d_candidates.json \
  /data/generated/latest_bbfs_3d_candidates.json \
  /data/generated/latest_prediction_run_audit.json; do
  code=$(http_code "https://$DOMAIN$p")
  if [ "$code" = "200" ]; then
    pass_msg "HTTPS $p = 200"
  else
    fail_msg "HTTPS $p = $code"
  fi
done

raw=$(http_code "https://$DOMAIN/data/all_results_from_source_file.json")
server=$(http_code "https://$DOMAIN/server/")
logs=$(http_code "https://$DOMAIN/logs/")
[ "$raw" = "403" ] && pass_msg "data mentah public = 403" || fail_msg "data mentah public = $raw"
[ "$server" = "403" ] && pass_msg "server/ public = 403" || fail_msg "server/ public = $server"
[ "$logs" = "403" ] && pass_msg "logs/ public = 403" || fail_msg "logs/ public = $logs"

{
  echo
  echo "== index script lines =="
  grep -n 'script' "$INDEX" 2>/dev/null || true
  echo
  echo "== loader first 220 lines =="
  nl -ba "$LOADER" 2>/dev/null | sed -n '1,220p' || true
  echo
  echo "== SUMMARY =="
  echo "PASS=$pass"
  echo "WARN=$warn"
  echo "FAIL=$fail"
  if [ "$fail" -eq 0 ]; then
    echo "FRONTEND_LOADER_STATUS=OK_LIGHT_FINAL"
  else
    echo "FRONTEND_LOADER_STATUS=NEEDS_REVIEW"
  fi
} | tee -a "$REPORT"

cat "$REPORT"
