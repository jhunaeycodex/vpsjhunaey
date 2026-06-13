#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
DOMAIN="${DOMAIN:-jhunaey.my.id}"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/frontend_inspect_latest.txt"
mkdir -p "$REPORT_DIR"

{
  echo "FRONTEND INSPECT LIGHT REPORT"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo "domain=$DOMAIN"
  echo
  echo "== index.html size and hash =="
  ls -lah "$WEB_ROOT/index.html" 2>/dev/null || true
  sha256sum "$WEB_ROOT/index.html" 2>/dev/null || true
  echo
  echo "== fetch / json / data references in index.html =="
  grep -nEi 'fetch\(|\.json|data/generated|generated|manifest|markets|latest_|DATA|ENDPOINT|API|XMLHttpRequest' "$WEB_ROOT/index.html" 2>/dev/null || true
  echo
  echo "== external-looking references in index/assets =="
  grep -RInE 'https?://|//cdn|cdnjs|unpkg|jsdelivr|googleapis|gstatic|analytics|gtag|facebook|doubleclick|<script[^>]+src=|<link[^>]+href=' "$WEB_ROOT/index.html" "$WEB_ROOT/assets" 2>/dev/null | head -120 || true
  echo
  echo "== local generated JSON HTTP status =="
  for p in \
    /data/generated/manifest.json \
    /data/generated/markets.json \
    /data/generated/latest_bbfs_7digit.json \
    /data/generated/latest_next_draw.json \
    /data/generated/latest_prediction_run_audit.json; do
    code=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$DOMAIN$p" 2>/dev/null || true)
    echo "$code https://$DOMAIN$p"
  done
  echo
  echo "== first 220 lines of index.html =="
  nl -ba "$WEB_ROOT/index.html" 2>/dev/null | sed -n '1,220p' || true
} | tee "$REPORT"

echo
 echo "Saved: $REPORT"
