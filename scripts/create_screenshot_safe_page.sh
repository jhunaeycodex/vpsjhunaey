#!/usr/bin/env bash
set -euo pipefail

WEB_ROOT="${WEB_ROOT:-/var/www/html/prediksi}"
REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/reports"
REPORT="$REPORT_DIR/screenshot_safe_page_latest.txt"
PAGE="$WEB_ROOT/screenshot.html"

mkdir -p "$REPORT_DIR" "$WEB_ROOT"
{
  echo "SCREENSHOT SAFE PAGE"
  echo "generated_at=$(date -Is)"
  echo "web_root=$WEB_ROOT"
} > "$REPORT"

cat > "$PAGE" <<'HTML'
<!doctype html>
<html lang="id">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Screenshot Safe</title>
  <style>
    *{box-sizing:border-box;-webkit-user-select:text!important;user-select:text!important;-webkit-touch-callout:default!important}
    html,body{margin:0;min-height:100%;background:#ffffff!important;color:#0f172a!important;font-family:Arial,Helvetica,sans-serif!important;filter:none!important;-webkit-filter:none!important}
    main{max-width:760px;margin:0 auto;padding:28px 18px 60px}
    .card{border:1px solid #cbd5e1;border-radius:16px;padding:22px;background:#fff;box-shadow:0 8px 30px rgba(15,23,42,.08)}
    h1{margin:0 0 8px;font-size:28px;line-height:1.15}
    p{font-size:16px;line-height:1.55;margin:10px 0}.ok{display:inline-block;margin:10px 0 16px;padding:8px 12px;border-radius:999px;background:#dcfce7;color:#166534;font-weight:700}.btns{display:flex;gap:10px;flex-wrap:wrap;margin-top:18px}button,a.btn{appearance:none;border:1px solid #334155;border-radius:999px;background:#0f172a;color:#fff;text-decoration:none;padding:11px 14px;font:inherit;cursor:pointer}button:hover,a.btn:hover{background:#334155}.note{margin-top:18px;padding:12px;border-radius:12px;background:#f8fafc;border:1px solid #e2e8f0;color:#334155;font-size:14px}
    @media print{button,a.btn{display:none!important}.card{box-shadow:none}main{padding:0}.note{break-inside:avoid}}
  </style>
</head>
<body>
  <main>
    <section class="card">
      <h1>Screenshot Safe Page</h1>
      <div class="ok">SCREENSHOT DIIZINKAN</div>
      <p>Halaman ini dibuat khusus untuk pengambilan screenshot atau simpan PDF. Tidak ada data berat, tidak ada overlay, tidak ada anti-screenshot, tidak ada CDN, dan tidak ada script penghalang.</p>
      <p>Gunakan halaman ini jika dashboard utama masih sulit di-screenshot dari browser atau aplikasi tertentu.</p>
      <div class="btns">
        <button type="button" onclick="window.print()">Cetak / Simpan PDF</button>
        <a class="btn" href="./">Kembali ke Dashboard</a>
      </div>
      <div class="note">Jika screenshot tetap gagal di halaman ini, pembatasnya berasal dari aplikasi/browser/perangkat, bukan dari website. Buka URL ini di Chrome/Safari biasa, bukan browser di dalam WhatsApp/Telegram/Facebook.</div>
    </section>
  </main>
</body>
</html>
HTML

chown www-data:www-data "$PAGE" 2>/dev/null || true
chmod 644 "$PAGE"

if [ -f "$PAGE" ] && grep -q 'SCREENSHOT DIIZINKAN' "$PAGE"; then
  echo "screenshot_url=/screenshot.html" | tee -a "$REPORT"
  echo "SCREENSHOT_SAFE_PAGE_STATUS=OK" | tee -a "$REPORT"
else
  echo "SCREENSHOT_SAFE_PAGE_STATUS=FAILED" | tee -a "$REPORT"
  exit 1
fi
