#!/usr/bin/env bash
set -euo pipefail

DOMAIN="jhunaey.my.id"
WEB_ROOT="/var/www/html/prediksi"
SITE_AVAILABLE="/etc/nginx/sites-available/${DOMAIN}"
SITE_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}"
REPORT_DIR="/root/vpsjhunaey/reports"
REPORT="${REPORT_DIR}/final_fix_prediksi_nginx_latest.txt"
TS="$(date +%Y%m%d_%H%M%S)"

if [ "$(id -u)" != "0" ]; then
  echo "ERROR: jalankan sebagai root"
  exit 1
fi

mkdir -p "$REPORT_DIR" "$WEB_ROOT" "$WEB_ROOT/backups/nginx" "$WEB_ROOT/backups/frontend"

{
  echo "FINAL FIX PREDIKSI NGINX"
  echo "generated_at=$(date -Is)"
  echo "domain=$DOMAIN"
  echo "web_root=$WEB_ROOT"
} > "$REPORT"

if [ -f "$SITE_AVAILABLE" ]; then
  cp -a "$SITE_AVAILABLE" "$WEB_ROOT/backups/nginx/${DOMAIN}.bak_${TS}"
fi

if [ -f "$WEB_ROOT/index.html" ]; then
  cp -a "$WEB_ROOT/index.html" "$WEB_ROOT/backups/frontend/index.html.before_final_nginx_${TS}.bak"
  python3 - <<'PY' "$WEB_ROOT/index.html"
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8', errors='ignore')
patterns = [
    r'\s*<link[^>]+assets/css/screenshot-tools\.css[^>]*>\s*',
    r'\s*<link[^>]+assets/css/screenshot-allow\.css[^>]*>\s*',
    r'\s*<script[^>]+assets/js/screenshot-tools\.js[^>]*>\s*</script>\s*',
    r'\s*<script[^>]+assets/js/screenshot-allow\.js[^>]*>\s*</script>\s*',
]
for pat in patterns:
    s = re.sub(pat, '\n', s, flags=re.I)
p.write_text(s, encoding='utf-8')
PY
fi

rm -f "$WEB_ROOT/screenshot.html" \
      "$WEB_ROOT/assets/js/screenshot-tools.js" "$WEB_ROOT/assets/css/screenshot-tools.css" \
      "$WEB_ROOT/assets/js/screenshot-allow.js" "$WEB_ROOT/assets/css/screenshot-allow.css"

cat > "$SITE_AVAILABLE" <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name jhunaey.my.id www.jhunaey.my.id;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name jhunaey.my.id www.jhunaey.my.id;

    ssl_certificate /etc/letsencrypt/live/jhunaey.my.id/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/jhunaey.my.id/privkey.pem;

    root /var/www/html/prediksi;
    index index.html;

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    location = /data/all_results_from_source_file.json { return 403; }
    location = /prediksi/data/all_results_from_source_file.json { return 403; }
    location ^~ /server/ { return 403; }
    location ^~ /logs/ { return 403; }
    location ^~ /prediksi/server/ { return 403; }
    location ^~ /prediksi/logs/ { return 403; }

    location ^~ /assets/ {
        alias /var/www/html/prediksi/assets/;
        try_files $uri =404;
    }

    location ^~ /prediksi/assets/ {
        alias /var/www/html/prediksi/assets/;
        try_files $uri =404;
    }

    location ^~ /data/generated/ {
        alias /var/www/html/prediksi/data/generated/;
        default_type application/json;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate" always;
        try_files $uri =404;
    }

    location ^~ /prediksi/data/generated/ {
        alias /var/www/html/prediksi/data/generated/;
        default_type application/json;
        add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate" always;
        try_files $uri =404;
    }

    location = /prediksi { return 301 /prediksi/; }

    location /prediksi/ {
        alias /var/www/html/prediksi/;
        index index.html;
        try_files $uri $uri/ /prediksi/index.html;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

ln -sfn "$SITE_AVAILABLE" "$SITE_ENABLED"
nginx -t
systemctl reload nginx

check() {
  local name="$1"
  local url="$2"
  local code
  code="$(curl -k -s -o /tmp/final_fix_body -w '%{http_code}' --max-time 12 "$url" || true)"
  echo "${name}=${code}" | tee -a "$REPORT"
}

{
  echo "== HTTP STATUS =="
} | tee -a "$REPORT"
check root "https://${DOMAIN}/"
check prediksi_root "https://${DOMAIN}/prediksi/"
check root_data_loader "https://${DOMAIN}/assets/js/data-loader.js"
check prediksi_data_loader "https://${DOMAIN}/prediksi/assets/js/data-loader.js"
check root_dashboard_js "https://${DOMAIN}/assets/js/dashboard.js"
check prediksi_dashboard_js "https://${DOMAIN}/prediksi/assets/js/dashboard.js"
check root_markets_json "https://${DOMAIN}/data/generated/markets.json"
check prediksi_markets_json "https://${DOMAIN}/prediksi/data/generated/markets.json"
check root_server "https://${DOMAIN}/server/"
check prediksi_server "https://${DOMAIN}/prediksi/server/"
check root_logs "https://${DOMAIN}/logs/"
check prediksi_logs "https://${DOMAIN}/prediksi/logs/"
check root_raw "https://${DOMAIN}/data/all_results_from_source_file.json"
check prediksi_raw "https://${DOMAIN}/prediksi/data/all_results_from_source_file.json"

{
  echo "== HEADER CHECK =="
  curl -k -I -s --max-time 12 "https://${DOMAIN}/prediksi/assets/js/data-loader.js" | head -20
  curl -k -I -s --max-time 12 "https://${DOMAIN}/prediksi/data/generated/markets.json" | head -20
  echo "== BODY TYPE CHECK =="
  printf 'data_loader_first_40='; curl -k -s --max-time 12 "https://${DOMAIN}/prediksi/assets/js/data-loader.js" | head -c 40; echo
  printf 'markets_first_40='; curl -k -s --max-time 12 "https://${DOMAIN}/prediksi/data/generated/markets.json" | head -c 40; echo
  echo "== INDEX SCRIPT CHECK =="
  grep -nE 'script src|stylesheet|screenshot' "$WEB_ROOT/index.html" || true
} | tee -a "$REPORT"

ok=1
for pair in \
  "root=200" \
  "prediksi_root=200" \
  "root_data_loader=200" \
  "prediksi_data_loader=200" \
  "root_dashboard_js=200" \
  "prediksi_dashboard_js=200" \
  "root_markets_json=200" \
  "prediksi_markets_json=200" \
  "root_server=403" \
  "prediksi_server=403" \
  "root_logs=403" \
  "prediksi_logs=403" \
  "root_raw=403" \
  "prediksi_raw=403"
do
  if ! grep -q "^${pair}$" "$REPORT"; then ok=0; fi
done

if [ "$ok" = "1" ]; then
  echo "FINAL_FIX_PREDIKSI_NGINX_STATUS=OK" | tee -a "$REPORT"
else
  echo "FINAL_FIX_PREDIKSI_NGINX_STATUS=NEEDS_REVIEW" | tee -a "$REPORT"
  exit 2
fi
