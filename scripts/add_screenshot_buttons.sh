#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
INDEX="$WEB_ROOT/index.html"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/screenshot_buttons_latest.txt"
BACKUP_DIR="$WEB_ROOT/backups/frontend"
TS="$(date +%Y%m%d_%H%M%S)"
CSS="$WEB_ROOT/assets/css/screenshot-tools.css"
JS="$WEB_ROOT/assets/js/screenshot-tools.js"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR" "$WEB_ROOT/assets/css" "$WEB_ROOT/assets/js"
{
  echo "SCREENSHOT BUTTONS INSTALL"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
} > "$REPORT"

if [ ! -f "$INDEX" ]; then
  echo "ERROR: index.html tidak ditemukan: $INDEX" | tee -a "$REPORT"
  exit 1
fi

cp -a "$INDEX" "$BACKUP_DIR/index.html.screenshot_$TS.bak"

cat > "$CSS" <<'CSS'
#screenshotTools{position:fixed;right:14px;bottom:14px;z-index:99999;display:flex;flex-wrap:wrap;gap:8px;max-width:min(440px,calc(100vw - 28px));padding:10px;border:1px solid rgba(148,163,184,.35);border-radius:14px;background:rgba(15,23,42,.94);box-shadow:0 12px 34px rgba(0,0,0,.35);backdrop-filter:blur(10px)}
#screenshotTools button{cursor:pointer;border:1px solid rgba(148,163,184,.35);border-radius:999px;padding:9px 12px;font:inherit;font-size:13px;line-height:1.2;color:#f8fafc;background:rgba(30,41,59,.96)}
#screenshotTools button:hover,#screenshotTools button:focus{outline:none;border-color:rgba(226,232,240,.78);background:rgba(51,65,85,.98)}
#screenshotTools small{flex-basis:100%;color:#cbd5e1;font-size:11px;line-height:1.35}.screenshot-compact details:not([open]),.screenshot-compact .debug-panel,.screenshot-compact .log-panel,.screenshot-compact .raw-audit{display:none!important}.screenshot-compact section,.screenshot-compact .card,.screenshot-compact .panel{break-inside:avoid;page-break-inside:avoid}
@media(max-width:720px){#screenshotTools{left:10px;right:10px;bottom:10px}#screenshotTools button{flex:1 1 auto}}
@media print{#screenshotTools{display:none!important}html,body{background:#fff!important;color:#000!important}body{-webkit-print-color-adjust:exact;print-color-adjust:exact}section,.card,.panel,table{break-inside:avoid;page-break-inside:avoid}button,input,select{box-shadow:none!important}}
CSS

cat > "$JS" <<'JS'
(function(){'use strict';function ready(fn){document.readyState==='loading'?document.addEventListener('DOMContentLoaded',fn,{once:true}):fn()}function btn(t,tip,fn){var b=document.createElement('button');b.type='button';b.textContent=t;b.title=tip;b.addEventListener('click',fn);return b}ready(function(){if(document.getElementById('screenshotTools'))return;var box=document.createElement('div');box.id='screenshotTools';box.setAttribute('aria-label','Screenshot tools');box.appendChild(btn('🖨️ Cetak / Simpan PDF','Buka dialog cetak. Pilih Save as PDF.',function(){window.print()}));box.appendChild(btn('📄 Mode Screenshot','Ringkas halaman agar mudah di-screenshot.',function(){document.body.classList.toggle('screenshot-compact');this.textContent=document.body.classList.contains('screenshot-compact')?'📄 Mode Normal':'📄 Mode Screenshot'}));box.appendChild(btn('⬆️ Ke Atas','Kembali ke atas halaman.',function(){window.scrollTo({top:0,left:0,behavior:'smooth'})}));var s=document.createElement('small');s.textContent='Untuk full halaman: tekan Cetak / Simpan PDF, lalu pilih Save as PDF. Untuk screenshot biasa: aktifkan Mode Screenshot.';box.appendChild(s);document.body.appendChild(box)})}());
JS

if ! grep -q 'assets/css/screenshot-tools.css' "$INDEX"; then
  if grep -qi '</head>' "$INDEX"; then
    sed -i '0,/<\/head>/s//  <link rel="stylesheet" href="assets\/css\/screenshot-tools.css">\n<\/head>/' "$INDEX"
  else
    printf '\n<link rel="stylesheet" href="assets/css/screenshot-tools.css">\n' >> "$INDEX"
  fi
fi

if ! grep -q 'assets/js/screenshot-tools.js' "$INDEX"; then
  if grep -qi '</body>' "$INDEX"; then
    sed -i '0,/<\/body>/s//  <script src="assets\/js\/screenshot-tools.js"><\/script>\n<\/body>/' "$INDEX"
  else
    printf '\n<script src="assets/js/screenshot-tools.js"></script>\n' >> "$INDEX"
  fi
fi

chown www-data:www-data "$INDEX" "$CSS" "$JS" 2>/dev/null || true
chmod 644 "$INDEX" "$CSS" "$JS"

if grep -q 'assets/css/screenshot-tools.css' "$INDEX" && grep -q 'assets/js/screenshot-tools.js' "$INDEX"; then
  echo "SCREENSHOT_BUTTONS_STATUS=OK" | tee -a "$REPORT"
else
  echo "SCREENSHOT_BUTTONS_STATUS=FAILED" | tee -a "$REPORT"
  exit 1
fi
