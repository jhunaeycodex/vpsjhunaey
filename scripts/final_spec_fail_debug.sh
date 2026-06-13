#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/final_spec_fail_debug_latest.txt"
mkdir -p "$REPORT_DIR"

{
  echo "FINAL SPEC FAIL DEBUG"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo
  echo "== EXTERNAL REFERENCE MATCHES: index/assets only =="
  echo "Pattern: https?:// OR protocol-relative src/href OR known CDN/tracking hosts"
  grep -RInE 'https?://|src=["'"'']//|href=["'"'']//|cdnjs|unpkg|jsdelivr|googleapis|gstatic|analytics|gtag|facebook|doubleclick' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null || true
  echo
  echo "== OVERCLAIM POSITIVE MATCHES: filtered =="
  echo "Pattern excludes lines with bukan/tidak/dilarang/disclaimer/larangan"
  grep -RInE 'angka jitu|pasti keluar|dijamin tembus|garansi menang|auto tembus|100% akurat|modal menang|wajib main|wajib pasang|target profit|martingale|recovery modal|strategi staking|nominal taruhan|instruksi pasang|ajakan bermain' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" "$WEB_ROOT/data/generated" 2>/dev/null | grep -vEi 'bukan|tidak|dilarang|disclaimer|larangan' | head -120 || true
  echo
  echo "== QUICK COUNTS =="
  external_count=$(grep -RInE 'https?://|src=["'"'']//|href=["'"'']//|cdnjs|unpkg|jsdelivr|googleapis|gstatic|analytics|gtag|facebook|doubleclick' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null | wc -l | tr -d ' ')
  overclaim_count=$(grep -RInE 'angka jitu|pasti keluar|dijamin tembus|garansi menang|auto tembus|100% akurat|modal menang|wajib main|wajib pasang|target profit|martingale|recovery modal|strategi staking|nominal taruhan|instruksi pasang|ajakan bermain' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" "$WEB_ROOT/data/generated" 2>/dev/null | grep -vEi 'bukan|tidak|dilarang|disclaimer|larangan' | wc -l | tr -d ' ')
  echo "external_count=$external_count"
  echo "overclaim_positive_count=$overclaim_count"
  if [ "$external_count" = "0" ] && [ "$overclaim_count" = "0" ]; then
    echo "DEBUG_STATUS=NO_MATCHES"
  else
    echo "DEBUG_STATUS=MATCHES_FOUND"
  fi
} | tee "$REPORT"
