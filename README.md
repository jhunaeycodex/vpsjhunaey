# VPS JHUNAEY Control

Repository ini dipakai sebagai **terminal kontrol berbasis GitHub** untuk memeriksa pemasangan VPS prediksi tanpa menjalankan proses analisis berat.

Fungsi utama:

- cek Nginx, HTTP/HTTPS, DNS, dan port 80/443;
- cek struktur `/var/www/html/prediksi`;
- cek file dashboard dan JSON generated;
- cek proteksi folder `server/`, `logs/`, dan file data mentah;
- membuat laporan teks di `reports/latest_status.txt` agar bisa diperiksa ulang.

> Catatan keamanan: script di repo ini tidak menjalankan SuperMax/BBFS dan tidak menjalankan command arbitrer otomatis. Semua perintah tetap dijalankan manual oleh pemilik VPS.

## Cara pakai di VPS

Masuk ke VPS sebagai `root`, lalu jalankan:

```bash
cd /root
apt update -y
apt install -y git curl

git clone https://github.com/jhunaeycodex/vpsjhunaey.git
cd vpsjhunaey
bash scripts/check_vps.sh
```

Laporan akan dibuat di:

```text
reports/latest_status.txt
```

Untuk melihat isi laporan di terminal:

```bash
cat reports/latest_status.txt
```

## Kirim laporan ke GitHub

Kalau GitHub di VPS sudah punya akses push, jalankan:

```bash
bash scripts/push_report.sh
```

Kalau push belum bisa, cukup copy isi `reports/latest_status.txt` dan kirim ke ChatGPT.

## Perintah penting

Cek ringan saja:

```bash
bash scripts/check_vps.sh
```

Cek + coba commit/push laporan:

```bash
bash scripts/push_report.sh
```

## Target hasil pemasangan

- `/` = `200 OK`
- `/data/generated/manifest.json` = `200 OK`
- `/data/generated/markets.json` = `200 OK`
- `/server/` = `403 Forbidden`
- `/logs/` = `403 Forbidden`
- `/data/all_results_from_source_file.json` = `403 Forbidden`

Jika hasil berbeda, kirim `reports/latest_status.txt` untuk dianalisis.
