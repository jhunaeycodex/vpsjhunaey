#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
DOMAIN="${DOMAIN:-jhunaey.my.id}"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/final_spec_cross_check_v2_latest.txt"
mkdir -p "$REPORT_DIR"

pass=0
warn=0
fail=0
pass_msg(){ pass=$((pass+1)); echo "PASS | $1" | tee -a "$REPORT"; }
warn_msg(){ warn=$((warn+1)); echo "WARN | $1" | tee -a "$REPORT"; }
fail_msg(){ fail=$((fail+1)); echo "FAIL | $1" | tee -a "$REPORT"; }
http_code(){ curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null || true; }
has_file(){ [ -f "$WEB_ROOT/$1" ]; }
has_dir(){ [ -d "$WEB_ROOT/$1" ]; }
json_has(){ grep -q "$2" "$WEB_ROOT/$1" 2>/dev/null; }

{
  echo "FINAL SPEC CROSS CHECK LIGHT V2"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo "domain=$DOMAIN"
  echo "note=Light check only. It does not run SuperMax heavy analysis. V2 avoids false positives for local script tags and negative disclaimers."
  echo
} > "$REPORT"

[ "$WEB_ROOT" = "/var/www/html/prediksi" ] && pass_msg "web root sesuai /var/www/html/prediksi" || fail_msg "web root tidak sesuai: $WEB_ROOT"
for d in assets assets/js data data/generated data/generated/markets server logs; do
  has_dir "$d" && pass_msg "folder $d ada" || fail_msg "folder $d tidak ada"
done
for f in index.html data/all_results_from_source_file.json server/analyze.js server/run_analysis.sh server/config.json server/markets_schedule.json; do
  has_file "$f" && pass_msg "file $f ada" || fail_msg "file $f tidak ada"
done
has_file "assets/js/app.js" && pass_msg "assets/js/app.js tersedia" || warn_msg "assets/js/app.js belum ada; frontend memakai loader/dashboard split"
has_file "assets/css/style.css" && pass_msg "assets/css/style.css tersedia" || warn_msg "assets/css/style.css belum ada; CSS masih inline di index.html"

root_code=$(http_code "https://$DOMAIN/")
prediksi_code=$(http_code "https://$DOMAIN/prediksi/")
[ "$root_code" = "200" ] && pass_msg "https://$DOMAIN/ aktif 200" || fail_msg "root domain bukan 200: $root_code"
[ "$prediksi_code" = "200" ] && pass_msg "https://$DOMAIN/prediksi/ aktif 200" || warn_msg "https://$DOMAIN/prediksi/ belum 200 ($prediksi_code)"

mandatory_json=(
  manifest.json markets.json latest_summary.json latest_next_draw.json latest_backtest.json
  latest_rolling_validation.json latest_holdout_recent_test.json latest_model_objective.json latest_warnings.json
  latest_super_max_summary.json latest_super_max_search_space.json latest_super_max_model_candidates.json latest_super_max_final_decision.json
  latest_model_freeze_audit.json latest_prediction_gate.json latest_champion_challenger.json latest_holdout_penalty.json
  latest_analyzer_config_snapshot.json latest_prediction_run_audit.json latest_prediction_readiness.json latest_data_freshness.json latest_next_draw_target.json
  latest_bbfs_7digit.json latest_bbfs_2d_candidates.json latest_bbfs_3d_candidates.json latest_bbfs_audit.json
)
for f in "${mandatory_json[@]}"; do
  has_file "data/generated/$f" && pass_msg "data/generated/$f ada" || fail_msg "data/generated/$f tidak ada"
done

json_has "data/generated/manifest.json" '"bbfs_enabled": true' && pass_msg "manifest bbfs_enabled=true" || fail_msg "manifest bbfs_enabled=true tidak ditemukan"
json_has "data/generated/manifest.json" 'BBFS_7_DIGIT_UTAMA' && pass_msg "manifest display_mode BBFS_7_DIGIT_UTAMA" || fail_msg "display_mode BBFS_7_DIGIT_UTAMA tidak ditemukan"
json_has "data/generated/latest_next_draw.json" 'bbfs' && pass_msg "latest_next_draw memuat field bbfs" || warn_msg "latest_next_draw belum jelas memuat field bbfs"
json_has "data/generated/latest_bbfs_7digit.json" 'bbfs_digits' && pass_msg "latest_bbfs_7digit memuat bbfs_digits" || fail_msg "latest_bbfs_7digit tidak memuat bbfs_digits"
json_has "data/generated/latest_bbfs_2d_candidates.json" 'candidates' && pass_msg "latest_bbfs_2d_candidates memuat candidates" || fail_msg "latest_bbfs_2d_candidates tidak memuat candidates"
json_has "data/generated/latest_bbfs_3d_candidates.json" 'candidates' && pass_msg "latest_bbfs_3d_candidates memuat candidates" || fail_msg "latest_bbfs_3d_candidates tidak memuat candidates"

schema_missing=0
for f in "${mandatory_json[@]}"; do
  if [ -f "$WEB_ROOT/data/generated/$f" ] && ! grep -q 'schema_version' "$WEB_ROOT/data/generated/$f" 2>/dev/null; then
    echo "SCHEMA_MISSING | $f" >> "$REPORT"
    schema_missing=$((schema_missing+1))
  fi
done
[ "$schema_missing" -eq 0 ] && pass_msg "schema_version ada pada semua JSON wajib yang ditemukan" || warn_msg "schema_version belum ada pada $schema_missing JSON wajib; lihat SCHEMA_MISSING"

if grep -q 'assets/js/data-loader.js' "$WEB_ROOT/index.html" 2>/dev/null; then pass_msg "index memuat data-loader lokal"; else fail_msg "index tidak memuat data-loader lokal"; fi
if grep -q 'data/generated/manifest.json' "$WEB_ROOT/assets/js/data-loader.js" 2>/dev/null && grep -q 'data/generated/markets.json' "$WEB_ROOT/assets/js/data-loader.js" 2>/dev/null; then
  pass_msg "frontend loader membaca manifest dan markets dari data/generated"
else
  fail_msg "frontend loader tidak jelas membaca generated JSON utama"
fi

# External reference: only actual http(s), protocol-relative CDN, known external hostnames.
if grep -RInE 'https?://|src=["'"'']//|href=["'"'']//|cdnjs|unpkg|jsdelivr|googleapis|gstatic|analytics|gtag|facebook|doubleclick' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null | head -50 >> "$REPORT"; then
  fail_msg "frontend/assets memiliki referensi eksternal eksplisit; lihat laporan"
else
  pass_msg "frontend/assets tidak memiliki referensi eksternal eksplisit"
fi

if grep -RIn 'localStorage' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null >> "$REPORT"; then fail_msg "localStorage ditemukan di frontend/assets"; else pass_msg "localStorage tidak ditemukan"; fi

for item in "server/:403" "logs/:403" "data/all_results_from_source_file.json:403"; do
  path="${item%%:*}"; expected="${item##*:}"; code=$(http_code "https://$DOMAIN/$path")
  [ "$code" = "$expected" ] && pass_msg "public /$path = $expected" || fail_msg "public /$path = $code, expected $expected"
done

if find "$WEB_ROOT" -maxdepth 1 -name '.*' | grep -q .; then find "$WEB_ROOT" -maxdepth 1 -name '.*' -ls >> "$REPORT" 2>/dev/null || true; fail_msg "dotfile/dotdir ditemukan di web root"; else pass_msg "tidak ada dotfile/dotdir di web root"; fi
if find "$WEB_ROOT" -maxdepth 3 -type f \( -name '*.key' -o -name '*.pem' -o -name '.env' -o -name 'id_rsa*' \) | grep -q .; then find "$WEB_ROOT" -maxdepth 3 -type f \( -name '*.key' -o -name '*.pem' -o -name '.env' -o -name 'id_rsa*' \) -ls >> "$REPORT" 2>/dev/null || true; fail_msg "file sensitif ditemukan di web root"; else pass_msg "tidak ada file secret umum di web root"; fi

if ps aux | grep -E 'server/analyze.js|run_analysis.sh super-max|supermax_finalize' | grep -v grep >> "$REPORT"; then fail_msg "proses analyzer berat sedang berjalan saat cross-check ringan"; else pass_msg "tidak ada proses analyzer berat berjalan"; fi
if crontab -l 2>/dev/null | grep -E 'run_analysis|supermax|analyze.js' >> "$REPORT"; then warn_msg "root cron analyzer ditemukan; pastikan jadwal memang final"; else pass_msg "tidak ada root cron analyzer berat"; fi
if systemctl list-unit-files | grep -q 'prediksi-analysis'; then pass_msg "systemd prediksi-analysis unit tersedia"; else warn_msg "systemd prediksi-analysis belum tersedia; cron/timer masih opsional sebelum run berat"; fi

# Actual overclaim: flag positive claims, not negative disclaimers containing 'bukan/tidak'.
if grep -RInE 'angka jitu|pasti keluar|dijamin tembus|garansi menang|auto tembus|100% akurat|modal menang|wajib main|wajib pasang|target profit|martingale|recovery modal|strategi staking|nominal taruhan|instruksi pasang|ajakan bermain' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" "$WEB_ROOT/data/generated" 2>/dev/null | grep -vEi 'bukan|tidak|dilarang|disclaimer|larangan' | head -80 >> "$REPORT"; then
  fail_msg "ditemukan istilah overclaim/perjudian positif; lihat laporan"
else
  pass_msg "tidak ditemukan istilah overclaim/perjudian positif"
fi

if grep -q 'completed_with_warnings\|completed' "$WEB_ROOT/data/generated/latest_prediction_run_audit.json" 2>/dev/null; then pass_msg "latest_prediction_run_audit memiliki run_status completed/completed_with_warnings"; else warn_msg "latest_prediction_run_audit belum menunjukkan completed/completed_with_warnings"; fi
if grep -q '4708e8a7fc7ca728\|86933' "$WEB_ROOT/data/generated/latest_prediction_run_audit.json" "$WEB_ROOT/data/generated/manifest.json" 2>/dev/null; then pass_msg "output audit tampak terkait dataset full terbaru"; else warn_msg "output audit mungkin belum berasal dari full run dataset terbaru; run SuperMax berat belum final"; fi

{
  echo
  echo "== SUMMARY =="
  echo "PASS=$pass"
  echo "WARN=$warn"
  echo "FAIL=$fail"
  if [ "$fail" -eq 0 ]; then echo "FINAL_SPEC_CROSS_CHECK_STATUS=OK_LIGHT_WITH_WARNINGS"; else echo "FINAL_SPEC_CROSS_CHECK_STATUS=NEEDS_REVIEW"; fi
} | tee -a "$REPORT"

cat "$REPORT"
