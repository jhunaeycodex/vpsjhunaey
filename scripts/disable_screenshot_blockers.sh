#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
INDEX="$WEB_ROOT/index.html"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/disable_screenshot_blockers_latest.txt"
BACKUP_DIR="$WEB_ROOT/backups/frontend"
TS="$(date +%Y%m%d_%H%M%S)"
CSS="$WEB_ROOT/assets/css/screenshot-allow.css"
JS="$WEB_ROOT/assets/js/screenshot-allow.js"

mkdir -p "$REPORT_DIR" "$BACKUP_DIR" "$WEB_ROOT/assets/css" "$WEB_ROOT/assets/js"
{
  echo "DISABLE SCREENSHOT BLOCKERS"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
} > "$REPORT"

if [ ! -f "$INDEX" ]; then
  echo "ERROR: index.html tidak ditemukan: $INDEX" | tee -a "$REPORT"
  exit 1
fi

cp -a "$INDEX" "$BACKUP_DIR/index.html.disable_screenshot_$TS.bak"

# CSS override: allow normal capture, print, selection, and remove common privacy/anti-screenshot overlays.
cat > "$CSS" <<'CSS'
html, body, * {
  -webkit-user-select: text !important;
  user-select: text !important;
  -webkit-touch-callout: default !important;
}
html, body {
  filter: none !important;
  -webkit-filter: none !important;
  backdrop-filter: none !important;
  -webkit-backdrop-filter: none !important;
}
.no-screenshot,
.noScreenshot,
.screenshot-block,
.screenshotBlock,
.privacy-screen,
.privacyScreen,
.capture-block,
.captureBlock,
.screen-protect,
.screenProtect,
.watermark-blocker,
[data-no-screenshot="true"],
[data-screenshot-block="true"],
[data-privacy-screen="true"] {
  display: none !important;
  opacity: 0 !important;
  visibility: hidden !important;
  pointer-events: none !important;
}
@media print {
  html, body, * {
    visibility: visible !important;
    opacity: 1 !important;
    filter: none !important;
    -webkit-filter: none !important;
  }
  body::before,
  body::after {
    display: none !important;
    content: none !important;
  }
}
CSS

# JS capture mode: stop page-level event blockers from preventing screenshot/print/copy/context menu.
cat > "$JS" <<'JS'
(function(){
  'use strict';
  var ALLOW = true;
  function stopBlocker(e){
    if(!ALLOW) return;
    var t = (e && e.type) || '';
    if(t === 'contextmenu' || t === 'copy' || t === 'cut' || t === 'selectstart' || t === 'dragstart' || t === 'beforeprint' || t === 'afterprint'){
      e.stopImmediatePropagation();
      return true;
    }
    if(t === 'keydown'){
      var k = (e.key || '').toLowerCase();
      var screenshotKeys = (k === 'printscreen' || k === 'p' || k === 's' || k === 'c');
      if(screenshotKeys && (e.ctrlKey || e.metaKey || k === 'printscreen')){
        e.stopImmediatePropagation();
        return true;
      }
    }
  }
  ['contextmenu','copy','cut','selectstart','dragstart','keydown','beforeprint','afterprint','visibilitychange','blur'].forEach(function(type){
    window.addEventListener(type, stopBlocker, true);
    document.addEventListener(type, stopBlocker, true);
  });
  function removeOverlays(){
    var selectors = [
      '.no-screenshot','.noScreenshot','.screenshot-block','.screenshotBlock',
      '.privacy-screen','.privacyScreen','.capture-block','.captureBlock',
      '.screen-protect','.screenProtect','.watermark-blocker',
      '[data-no-screenshot="true"]','[data-screenshot-block="true"]','[data-privacy-screen="true"]'
    ];
    selectors.forEach(function(sel){
      document.querySelectorAll(sel).forEach(function(el){
        el.setAttribute('hidden','hidden');
        el.style.setProperty('display','none','important');
        el.style.setProperty('visibility','hidden','important');
        el.style.setProperty('opacity','0','important');
        el.style.setProperty('pointer-events','none','important');
      });
    });
    document.documentElement.style.setProperty('filter','none','important');
    document.body && document.body.style.setProperty('filter','none','important');
  }
  if(document.readyState === 'loading'){
    document.addEventListener('DOMContentLoaded', removeOverlays, {once:true});
  } else {
    removeOverlays();
  }
  setInterval(removeOverlays, 1500);
  window.__SCREENSHOT_ALLOWED__ = true;
}());
JS

# Inject CSS/JS if not already present.
if ! grep -q 'assets/css/screenshot-allow.css' "$INDEX"; then
  if grep -qi '</head>' "$INDEX"; then
    sed -i '0,/<\/head>/s//  <link rel="stylesheet" href="assets\/css\/screenshot-allow.css">\n<\/head>/' "$INDEX"
  else
    printf '\n<link rel="stylesheet" href="assets/css/screenshot-allow.css">\n' >> "$INDEX"
  fi
fi

if ! grep -q 'assets/js/screenshot-allow.js' "$INDEX"; then
  if grep -qi '</body>' "$INDEX"; then
    sed -i '0,/<\/body>/s//  <script src="assets\/js\/screenshot-allow.js"><\/script>\n<\/body>/' "$INDEX"
  else
    printf '\n<script src="assets/js/screenshot-allow.js"></script>\n' >> "$INDEX"
  fi
fi

# Patch common inline blockers if present, conservatively.
python3 - <<'PY' "$INDEX"
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8', errors='ignore')
repls = [
    (r'oncontextmenu\s*=\s*"return\s+false;?"', ''),
    (r'oncopy\s*=\s*"return\s+false;?"', ''),
    (r'oncut\s*=\s*"return\s+false;?"', ''),
    (r'onselectstart\s*=\s*"return\s+false;?"', ''),
]
for pat, rep in repls:
    s = re.sub(pat, rep, s, flags=re.I)
p.write_text(s, encoding='utf-8')
PY

chown www-data:www-data "$INDEX" "$CSS" "$JS" 2>/dev/null || true
chmod 644 "$INDEX" "$CSS" "$JS"

if grep -q 'assets/css/screenshot-allow.css' "$INDEX" && grep -q 'assets/js/screenshot-allow.js' "$INDEX"; then
  echo "DISABLE_SCREENSHOT_BLOCKERS_STATUS=OK" | tee -a "$REPORT"
else
  echo "DISABLE_SCREENSHOT_BLOCKERS_STATUS=FAILED" | tee -a "$REPORT"
  exit 1
fi
