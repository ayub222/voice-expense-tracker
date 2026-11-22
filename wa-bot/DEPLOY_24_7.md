# Deploy `wa-bot` 24/7 (Tetap Jalan Walau Laptop Mati)

Folder `wa-bot` sudah siap dijalankan 24 jam di server/cloud tanpa perlu menyalakan laptop.

## Opsi A: Linux VPS (Paling Stabil & Bisa Copy Sesi WA Tanpa Scan QR Ulang)
1. Upload folder `wa-bot/` dan folder `../storage/wa_auth/` ke server Linux (misal `/opt/voice-expense/wa-bot/` dan `/opt/voice-expense/storage/wa_auth/`).
2. Di server, install Node.js 20 + PM2:
   ```bash
   cd /opt/voice-expense/wa-bot
   npm ci --omit=dev
   npm install -g pm2
   pm2 start ecosystem.config.cjs
   pm2 save
   pm2 startup
   ```
3. Cek log & health check:
   ```bash
   pm2 logs voice-expense-wa-bot
   curl http://127.0.0.1:3000/health
   ```

## Opsi B: Railway / Fly.io / Koyeb (Docker)
1. Deploy folder `wa-bot/` menggunakan `Dockerfile` yang sudah tersedia.
2. **Penting:** Pasang **Persistent Volume** ke `/data` agar sesi login WhatsApp (`wa_auth`) tidak hilang saat container restart.
3. Set Environment Variables:
   - `API_BASE=https://voice-expense-tracker-olive.vercel.app/api.php`
   - `STORAGE_DIR=/data`
   - `PORT=3000`
4. Setelah container jalan, cek log container untuk scan QR code pertama kali (atau upload isi folder `storage/wa_auth` ke `/data/wa_auth`).

> **Catatan:** Jangan jalankan `wa-bot` di laptop dan di server secara bersamaan dengan akun WA (`wa_auth`) yang sama agar tidak bentrok (*conflict/logged out*). Matikan bot lokal di laptop setelah bot server 24/7 aktif.
