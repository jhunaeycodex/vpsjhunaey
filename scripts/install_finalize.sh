#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
DOMAIN="${DOMAIN:-jhunaey.my.id}"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/install_finalize_latest.txt"
TS="$(date +%Y%m%d_%H%M%S)"

run() {
  local title="$1"
  shift
  {
    echo
    echo "================================================================"
    echo "## $title"
    echo "================================================================"
    echo "+ $*"
  } >> "$REPORT"
  timeout 20s bash -lc "$*" >> "$REPORT" 2>&1
  echo "[exit_code=$?]" >> "$REPORT"
}

{
  echo "INSTALL FINALIZE REPORT"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo "domain=$DOMAIN"
} > "$REPORT"

echo "[1/9] Backup nginx config"
mkdir -p /root/vpsjhunaey_backup/nginx
nginx -T > "/root/vpsjhunaey_backup/nginx/nginx_T_$TS.conf" 2>/dev/null || true
cp -a /etc/nginx/sites-available "/root/vpsjhunaey_backup/nginx/sites-available_$TS" 2>/dev/null || true
cp -a /etc/nginx/sites-enabled "/root/vpsjhunaey_backup/nginx/sites-enabled_$TS" 2>/dev/null || true

run "NGINX SYNTAX" "nginx -t"
run "NGINX SERVICE" "systemctl is-active nginx; systemctl is-enabled nginx || true"
run "PORTS" "ss -ltnp | grep -E ':80|:443|nginx' || true"
run "CERTBOT CERTIFICATES" "certbot certificates 2>/dev/null || true"
run "CERTBOT TIMER" "systemctl list-timers | grep -E 'certbot|snap.certbot' || true; systemctl status certbot.timer --no-pager 2>/dev/null || true"
run "UFW STATUS" "ufw status verbose 2>/dev/null || true"
run "WEB PROTECTION HTTPS" "curl -k -I --max-time 10 https://$DOMAIN/; curl -k -I --max-time 10 https://$DOMAIN/data/generated/manifest.json; curl -k -I --max-time 10 https://$DOMAIN/data/generated/markets.json; curl -k -I --max-time 10 https://$DOMAIN/server/; curl -k -I --max-time 10 https://$DOMAIN/logs/; curl -k -I --max-time 10 https://$DOMAIN/data/all_results_from_source_file.json"
run "WEB ROOT SENSITIVE CHECK" "find $WEB_ROOT -maxdepth 1 -name '.*' -ls 2>/dev/null || true; find $WEB_ROOT -maxdepth 2 -type f \( -name '*.key' -o -name '*.pem' -o -name '*.env' -o -name 'id_rsa*' \) -ls 2>/dev/null || true"
run "PERMISSIONS SUMMARY" "stat -c '%U:%G %a %n' $WEB_ROOT $WEB_ROOT/index.html $WEB_ROOT/data $WEB_ROOT/data/generated $WEB_ROOT/server $WEB_ROOT/logs 2>/dev/null || true"
run "CRON CHECK" "crontab -l 2>/dev/null || true; ls -lah /etc/cron.d 2>/dev/null || true"
run "SWAP CHECK" "free -h; swapon --show || true"
run "PROCESS CHECK" "ps aux | grep -E 'analyze|run_analysis|supermax|node|nginx' | grep -v grep || true"

DOMAIN_HTTPS=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$DOMAIN/" 2>/dev/null || true)
MANIFEST_HTTPS=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$DOMAIN/data/generated/manifest.json" 2>/dev/null || true)
MARKETS_HTTPS=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$DOMAIN/data/generated/markets.json" 2>/dev/null || true)
SERVER_HTTPS=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$DOMAIN/server/" 2>/dev/null || true)
LOGS_HTTPS=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$DOMAIN/logs/" 2>/dev/null || true)
RAW_HTTPS=$(curl -k -sS -o /dev/null -w '%{http_code}' --max-time 10 "https://$DOMAIN/data/all_results_from_source_file.json" 2>/dev/null || true)

{
  echo
  echo "================================================================"
  echo "## SUMMARY"
  echo "================================================================"
  echo "domain_https=$DOMAIN_HTTPS"
  echo "manifest_https=$MANIFEST_HTTPS"
  echo "markets_https=$MARKETS_HTTPS"
  echo "server_https=$SERVER_HTTPS"
  echo "logs_https=$LOGS_HTTPS"
  echo "raw_data_https=$RAW_HTTPS"
  if [ "$DOMAIN_HTTPS" = "200" ] && [ "$MANIFEST_HTTPS" = "200" ] && [ "$MARKETS_HTTPS" = "200" ] && [ "$SERVER_HTTPS" = "403" ] && [ "$LOGS_HTTPS" = "403" ] && [ "$RAW_HTTPS" = "403" ]; then
    echo "INSTALL_FINALIZE_STATUS=OK"
  else
    echo "INSTALL_FINALIZE_STATUS=NEEDS_REVIEW"
  fi
} >> "$REPORT"

cat "$REPORT"
