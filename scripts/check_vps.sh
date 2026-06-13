#!/usr/bin/env bash
set -u

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
DOMAIN="${DOMAIN:-jhunaey.my.id}"
IP_ADDR="${IP_ADDR:-202.155.95.27}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$REPO_ROOT/reports"
mkdir -p "$REPORT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$REPORT_DIR/status_$TS.txt"
LATEST="$REPORT_DIR/latest_status.txt"

have_timeout() {
  command -v timeout >/dev/null 2>&1
}

run_cmd() {
  local title="$1"
  shift
  {
    echo
    echo "================================================================"
    echo "## $title"
    echo "================================================================"
    echo "+ $*"
  } >> "$REPORT"

  if have_timeout; then
    timeout 15s bash -lc "$*" >> "$REPORT" 2>&1
  else
    bash -lc "$*" >> "$REPORT" 2>&1
  fi

  local code=$?
  echo "[exit_code=$code]" >> "$REPORT"
}

http_code() {
  local url="$1"
  curl -k -sS -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || true
}

{
  echo "VPS JHUNAEY STATUS REPORT"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
  echo "domain=$DOMAIN"
  echo "ip=$IP_ADDR"
  echo "user=$(whoami)"
  echo "hostname=$(hostname)"
  echo "pwd=$(pwd)"
} > "$REPORT"

run_cmd "SYSTEM" "date -Is; hostnamectl 2>/dev/null || true; uname -a; uptime; whoami; id"
run_cmd "DISK AND MEMORY" "df -h; echo; free -h"
run_cmd "NODE VERSION" "node -v 2>/dev/null || true; npm -v 2>/dev/null || true"

run_cmd "NGINX STATUS" "systemctl is-active nginx || true; systemctl status nginx --no-pager -l || true"
run_cmd "NGINX TEST" "nginx -t"
run_cmd "PORT LISTEN" "ss -ltnp | grep -E ':80|:443|nginx' || true"
run_cmd "NGINX ACTIVE CONFIG SUMMARY" "nginx -T 2>/dev/null | grep -nE 'server_name|listen|root |location|return 403|deny all' || true"

run_cmd "DNS RESOLUTION" "getent hosts $DOMAIN || true; getent hosts www.$DOMAIN || true"

run_cmd "HTTP LOCAL ROOT" "curl -I --max-time 10 http://127.0.0.1/ || true"
run_cmd "HTTP LOCAL GENERATED MANIFEST" "curl -I --max-time 10 http://127.0.0.1/data/generated/manifest.json || true"
run_cmd "HTTP LOCAL GENERATED MARKETS" "curl -I --max-time 10 http://127.0.0.1/data/generated/markets.json || true"
run_cmd "HTTP LOCAL PROTECTED SERVER" "curl -I --max-time 10 http://127.0.0.1/server/ || true"
run_cmd "HTTP LOCAL PROTECTED LOGS" "curl -I --max-time 10 http://127.0.0.1/logs/ || true"
run_cmd "HTTP LOCAL PROTECTED RAW DATA" "curl -I --max-time 10 http://127.0.0.1/data/all_results_from_source_file.json || true"

run_cmd "HTTP DOMAIN ROOT" "curl -I --max-time 10 http://$DOMAIN/ || true"
run_cmd "HTTPS DOMAIN ROOT" "curl -k -I --max-time 10 https://$DOMAIN/ || true"
run_cmd "HTTP IP ROOT" "curl -I --max-time 10 http://$IP_ADDR/ || true"

run_cmd "WEB ROOT LIST" "ls -lah $WEB_ROOT || true"
run_cmd "SENSITIVE DOTFILES IN WEB ROOT" "find $WEB_ROOT -maxdepth 1 -name '.*' -ls 2>/dev/null || true"
run_cmd "DATA LIST" "ls -lah $WEB_ROOT/data || true"
run_cmd "GENERATED LIST" "ls -lah $WEB_ROOT/data/generated || true"
run_cmd "SERVER LIST" "ls -lah $WEB_ROOT/server || true"
run_cmd "LOGS LIST" "ls -lah $WEB_ROOT/logs || true"

run_cmd "MANIFEST HEAD" "head -80 $WEB_ROOT/data/generated/manifest.json 2>/dev/null || true"
run_cmd "MARKETS HEAD" "head -40 $WEB_ROOT/data/generated/markets.json 2>/dev/null || true"
run_cmd "LATEST AUDIT HEAD" "head -80 $WEB_ROOT/data/generated/latest_prediction_run_audit.json 2>/dev/null || true"

run_cmd "PROCESS CHECK" "ps aux | grep -E 'analyze|run_analysis|supermax|node|nginx' | grep -v grep || true"
run_cmd "CRON ROOT" "crontab -l 2>/dev/null || true"
run_cmd "JOURNAL NGINX LAST 80" "journalctl -u nginx -n 80 --no-pager 2>/dev/null || true"

LOCAL_ROOT_CODE="$(http_code http://127.0.0.1/)"
MANIFEST_CODE="$(http_code http://127.0.0.1/data/generated/manifest.json)"
MARKETS_CODE="$(http_code http://127.0.0.1/data/generated/markets.json)"
SERVER_CODE="$(http_code http://127.0.0.1/server/)"
LOGS_CODE="$(http_code http://127.0.0.1/logs/)"
RAW_CODE="$(http_code http://127.0.0.1/data/all_results_from_source_file.json)"
DOMAIN_CODE="$(http_code http://$DOMAIN/)"
HTTPS_CODE="$(http_code https://$DOMAIN/)"

{
  echo
  echo "================================================================"
  echo "## SUMMARY"
  echo "================================================================"
  echo "local_root_http=$LOCAL_ROOT_CODE"
  echo "manifest_http=$MANIFEST_CODE"
  echo "markets_http=$MARKETS_CODE"
  echo "server_protection_http=$SERVER_CODE"
  echo "logs_protection_http=$LOGS_CODE"
  echo "raw_data_protection_http=$RAW_CODE"
  echo "domain_http=$DOMAIN_CODE"
  echo "domain_https=$HTTPS_CODE"
  echo
  echo "EXPECTED:"
  echo "local_root_http=200"
  echo "manifest_http=200"
  echo "markets_http=200"
  echo "server_protection_http=403"
  echo "logs_protection_http=403"
  echo "raw_data_protection_http=403"
  echo
  if [ "$LOCAL_ROOT_CODE" = "200" ] && [ "$MANIFEST_CODE" = "200" ] && [ "$MARKETS_CODE" = "200" ] && [ "$SERVER_CODE" = "403" ] && [ "$LOGS_CODE" = "403" ] && [ "$RAW_CODE" = "403" ]; then
    echo "INSTALLATION_STATUS=OK_LIGHT_CHECK"
  else
    echo "INSTALLATION_STATUS=NEEDS_REVIEW"
  fi
} >> "$REPORT"

cp "$REPORT" "$LATEST"

echo "Report created: $REPORT"
echo "Latest report:  $LATEST"
echo
tail -40 "$LATEST"
