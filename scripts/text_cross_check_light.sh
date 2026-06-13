#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
DOMAIN="${DOMAIN:-jhunaey.my.id}"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/text_cross_check_latest.txt"
mkdir -p "$REPORT_DIR"

pass=0
fail=0
warn=0

note() { echo "$*" | tee -a "$REPORT"; }
check_pass() { pass=$((pass+1)); note "PASS | $1"; }
check_fail() { fail=$((fail+1)); note "FAIL | $1"; }
check_warn() { warn=$((warn+1)); note "WARN | $1"; }

http_code() {
  curl -k -sS -o /dev/null -w "%{http_code}" --max-time 10 "$1" 2>/dev/null || true
}

has_file() {
  [ -f "$WEB_ROOT/$1" ]
}

has_dir() {
  [ -d "$WEB_ROOT/$1" ]
}

json_grep() {
  local file="$1"
  local pattern="$2"
  grep -q "$pattern" "$WEB_ROOT/$file" 2>/dev/null
}

{
  echo "TEXT FINAL CROSS CHECK LIGHT REPORT"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo "domain=$DOMAIN"
  echo
  echo "Target utama dari teks final: VPS-first, frontend baca JSON generated, BBFS 7 Digit Utama sebagai output user, Node analyzer, Nginx static, tanpa API/CDN/tracking/framework eksternal, tanpa database wajib, proteksi server/logs/data mentah, no heavy browser compute, no proses berat sebelum diperintah."
  echo
} > "$REPORT"

note "== 1. STRUKTUR VPS-FIRST =="
has_file "index.html" && check_pass "index.html ada di web root" || check_fail "index.html tidak ada"
has_dir "data" && check_pass "folder data/ ada" || check_fail "folder data/ tidak ada"
has_file "data/all_results_from_source_file.json" && check_pass "data mentah JSON ada" || check_fail "data mentah JSON tidak ada"
has_dir "data/generated" && check_pass "folder data/generated/ ada" || check_fail "folder data/generated/ tidak ada"
has_dir "server" && check_pass "folder server/ ada" || check_fail "folder server/ tidak ada"
has_dir "logs" && check_pass "folder logs/ ada" || check_fail "folder logs/ tidak ada"

note "\n== 2. NODE ANALYZER =="
has_file "server/analyze.js" && check_pass "server/analyze.js ada" || check_fail "server/analyze.js tidak ada"
has_file "server/run_analysis.sh" && check_pass "server/run_analysis.sh ada" || check_fail "server/run_analysis.sh tidak ada"
has_file "server/supermax_finalize.js" && check_pass "server/supermax_finalize.js ada" || check_warn "server/supermax_finalize.js tidak ada"
node -v >> "$REPORT" 2>&1 && check_pass "Node.js tersedia" || check_fail "Node.js tidak tersedia"

note "\n== 3. FRONTEND BACA JSON GENERATED =="
if grep -q "data/generated" "$WEB_ROOT/index.html" 2>/dev/null; then
  check_pass "index.html membaca data/generated"
else
  check_fail "index.html tidak terlihat membaca data/generated"
fi
if grep -q "all_results_from_source_file.json" "$WEB_ROOT/index.html" 2>/dev/null; then
  check_warn "index.html menyebut data mentah; pastikan tidak fetch langsung data mentah"
else
  check_pass "index.html tidak menyebut data mentah langsung"
fi

note "\n== 4. OUTPUT JSON WAJIB =="
for f in \
  data/generated/manifest.json \
  data/generated/markets.json \
  data/generated/latest_bbfs_7digit.json \
  data/generated/latest_bbfs_2d_candidates.json \
  data/generated/latest_bbfs_3d_candidates.json \
  data/generated/latest_bbfs_audit.json \
  data/generated/latest_prediction_gate.json \
  data/generated/latest_prediction_readiness.json \
  data/generated/latest_backtest.json \
  data/generated/latest_rolling_validation.json \
  data/generated/latest_holdout_recent_test.json \
  data/generated/latest_super_max_summary.json \
  data/generated/latest_prediction_run_audit.json; do
  has_file "$f" && check_pass "$f ada" || check_warn "$f belum ada"
done

note "\n== 5. BBFS 7 DIGIT UTAMA =="
json_grep "data/generated/manifest.json" '"bbfs_enabled": true' && check_pass "manifest: bbfs_enabled=true" || check_fail "manifest: bbfs_enabled=true tidak ditemukan"
json_grep "data/generated/manifest.json" 'BBFS_7_DIGIT_UTAMA' && check_pass "manifest: display_mode BBFS_7_DIGIT_UTAMA" || check_fail "manifest: display_mode BBFS_7_DIGIT_UTAMA tidak ditemukan"
if has_file "data/generated/latest_bbfs_7digit.json"; then
  check_pass "latest_bbfs_7digit.json tersedia"
else
  check_fail "latest_bbfs_7digit.json tidak tersedia"
fi

note "\n== 6. WEB ACCESS DAN PROTEKSI =="
root_code=$(http_code "https://$DOMAIN/")
manifest_code=$(http_code "https://$DOMAIN/data/generated/manifest.json")
markets_code=$(http_code "https://$DOMAIN/data/generated/markets.json")
server_code=$(http_code "https://$DOMAIN/server/")
logs_code=$(http_code "https://$DOMAIN/logs/")
raw_code=$(http_code "https://$DOMAIN/data/all_results_from_source_file.json")
[ "$root_code" = "200" ] && check_pass "HTTPS root 200" || check_fail "HTTPS root bukan 200: $root_code"
[ "$manifest_code" = "200" ] && check_pass "manifest public 200" || check_fail "manifest bukan 200: $manifest_code"
[ "$markets_code" = "200" ] && check_pass "markets public 200" || check_fail "markets bukan 200: $markets_code"
[ "$server_code" = "403" ] && check_pass "server/ terlindungi 403" || check_fail "server/ bukan 403: $server_code"
[ "$logs_code" = "403" ] && check_pass "logs/ terlindungi 403" || check_fail "logs/ bukan 403: $logs_code"
[ "$raw_code" = "403" ] && check_pass "data mentah terlindungi 403" || check_fail "data mentah bukan 403: $raw_code"

note "\n== 7. LARANGAN EKSTERNAL FRONTEND =="
if grep -RInE 'https?://|//cdn|cdnjs|unpkg|jsdelivr|googleapis|gstatic|analytics|gtag|facebook|doubleclick' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null | head -50 >> "$REPORT"; then
  check_warn "Ditemukan referensi eksternal di frontend/assets; lihat baris di laporan"
else
  check_pass "Tidak ditemukan referensi eksternal umum di frontend/assets"
fi
if grep -RInE '<script[^>]+src=|<link[^>]+href=' "$WEB_ROOT/index.html" 2>/dev/null | grep -E 'https?://|//|cdn|unpkg|jsdelivr' >> "$REPORT"; then
  check_fail "Ada script/link eksternal eksplisit"
else
  check_pass "Tidak ada script/link eksternal eksplisit di index.html"
fi
if grep -RIn 'localStorage' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null >> "$REPORT"; then
  check_warn "localStorage ditemukan; teks final melarang data sensitif di localStorage"
else
  check_pass "localStorage tidak ditemukan"
fi

note "\n== 8. DATABASE/API/SCRAPING =="
if pgrep -af 'mysql|mariadb|mongod|postgres|redis' | grep -v grep >> "$REPORT"; then
  check_warn "Ada proses database/service terkait; cek apakah memang diperlukan"
else
  check_pass "Tidak ada proses database umum berjalan"
fi
if grep -RInE 'fetch\(|XMLHttpRequest|axios|http\.request|https\.request' "$WEB_ROOT/server" "$WEB_ROOT/index.html" 2>/dev/null | head -80 >> "$REPORT"; then
  check_warn "Ada fetch/request di kode; cek apakah hanya fetch JSON lokal"
else
  check_pass "Tidak terlihat request eksternal eksplisit"
fi

note "\n== 9. PROSES BERAT DAN CRON =="
if ps aux | grep -E 'server/analyze.js|run_analysis.sh super-max|supermax_finalize' | grep -v grep >> "$REPORT"; then
  check_fail "Proses analyzer/SuperMax sedang berjalan; seharusnya belum saat tahap ringan"
else
  check_pass "Tidak ada proses SuperMax/analyzer berat berjalan"
fi
if crontab -l 2>/dev/null | grep -E 'run_analysis|supermax|analyze.js' >> "$REPORT"; then
  check_warn "Ada cron analyzer; pastikan memang jadwal final nanti"
else
  check_pass "Tidak ada cron analyzer berat di root"
fi

note "\n== 10. DISCLAIMER / NO CLAIM PASTI =="
if grep -RInE 'ranking statistik|bukan jaminan|bukan angka pasti|historis|statistik' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null | head -20 >> "$REPORT"; then
  check_pass "Teks disclaimer/statistik ditemukan"
else
  check_warn "Disclaimer statistik tidak jelas ditemukan di frontend"
fi

note "\n== SUMMARY =="
note "PASS=$pass"
note "WARN=$warn"
note "FAIL=$fail"
if [ "$fail" -eq 0 ]; then
  note "TEXT_CROSS_CHECK_STATUS=OK_LIGHT_FINAL"
else
  note "TEXT_CROSS_CHECK_STATUS=NEEDS_REVIEW"
fi

cat "$REPORT"
