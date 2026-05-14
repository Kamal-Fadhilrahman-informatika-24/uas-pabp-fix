# 🎯 SpinDecide v2.0 — Panduan Lengkap

> Spin wheel app dengan fitur Truth or Dare, Double Spin, dan Multiplayer Realtime.
> Stack: Vanilla HTML/CSS/JS + Supabase + Socket.IO

---

## 📁 Struktur Folder Terbaru

```
spinwheel-fun/
├── login.html              — Halaman login (existing)
├── register.html           — Halaman register (existing)
├── dashboard.html          — Spin wheel utama (navbar diupdate)
├── history.html            — Riwayat spin (navbar diupdate)
├── truth-dare.html         ★ BARU — Halaman Truth or Dare
├── double-spin.html        ★ BARU — Halaman Double Spin
├── multiplayer.html        ★ BARU — Halaman Main Bareng
├── style.css               — Global styles (diupdate)
├── truth-dare.css          ★ BARU — Styles Truth or Dare
├── double-spin.css         ★ BARU — Styles Double Spin
├── multiplayer.css         ★ BARU — Styles Multiplayer
├── supabase.js             — Konfigurasi Supabase (existing)
├── auth.js                 — Logika auth (existing)
├── spin.js                 — Logika spin wheel (existing)
├── history.js              — Logika riwayat (existing)
├── truth-dare-data.js      ★ BARU — Data pertanyaan & tantangan
├── truth-dare.js           ★ BARU — Logika Truth or Dare
├── double-spin.js          ★ BARU — Logika Double Spin
├── multiplayer.js          ★ BARU — Client Socket.IO
├── server.js               ★ BARU — Backend Socket.IO (Node.js)
├── package.json            ★ BARU — Dependencies backend
├── manifest.json           — PWA manifest (existing)
└── sw.js                   — Service Worker (diupdate ke v2)
```

---

## 🚀 Cara Menjalankan

### Website (Frontend)
```bash
# Gunakan Live Server VSCode, atau:
npx serve .
# Buka: http://localhost:5500/login.html
```

### Backend Realtime (untuk Multiplayer)
```bash
npm install
npm run dev      # development (nodemon)
npm start        # production
# Server: http://localhost:3001
```

### Konfigurasi URL Backend
Di `multiplayer.html`, ganti URL production:
```javascript
window.SOCKET_SERVER_URL = window.location.hostname === 'localhost'
  ? 'http://localhost:3001'
  : 'https://URL-BACKEND-KAMU.onrender.com'; // ← ganti ini
```

---

## 🎭 Cara Kerja Truth or Dare

- Pilih TRUTH atau DARE → kartu random tampil dengan animasi
- Klik Random Lagi untuk kartu baru dari pool yang sudah diacak
- Player tracker melacak giliran otomatis
- Stats tersimpan di localStorage
- **Edit data:** ubah `truth-dare-data.js` untuk tambah pertanyaan/tantangan

## ⚡ Cara Kerja Double Spin

- Tambah item ke 2 roda berbeda (contoh: Nama | Tugas)
- Klik DOUBLE SPIN → kedua canvas berputar dalam 1 animasi loop
- Hasil otomatis dipasangkan: Roda A[index] → Roda B[index]
- Data disimpan localStorage, riwayat pasangan tampil di bawah

## 🌐 Cara Kerja Multiplayer

```
Host: room:create → server generate kode 6 huruf → room:joined
Guest: room:join(kode) → server validasi → room:joined + broadcast ke semua
Host: spin:start → server broadcast ke semua → semua animasi sinkron
Host: spin:result → server broadcast → semua lihat hasil bersamaan
```

Events: `room:create`, `room:join`, `room:leave`, `room:playerJoined`, `room:playerLeft`, `room:updateOptions`, `room:optionsUpdated`, `spin:start`, `spin:result`

---

## 🌍 Deploy

### Frontend → Vercel/Netlify
- Vercel: `npx vercel` atau drag-drop di vercel.com
- Netlify: drag-drop folder ke app.netlify.com/drop

### Backend → Render.com (Free)
1. Push `server.js` + `package.json` ke GitHub
2. Render.com → New Web Service → connect repo
3. Build: `npm install` | Start: `node server.js`
4. Copy URL deploy → update `SOCKET_SERVER_URL` di `multiplayer.html`

---

## 🧪 Testing

**Truth or Dare:** Login → Truth or Dare → pilih mode → klik Random Lagi → cek stats

**Double Spin:** Login → Double Spin → tambah 3+ item tiap roda → DOUBLE SPIN! → cek pasangan

**Multiplayer:**
1. Tab 1: Login → Main Bareng → Buat Room → catat kode
2. Tab 2: Login → Main Bareng → Gabung → masukkan kode
3. Tab 1 (host): tambah pilihan → verifikasi Tab 2 update
4. Tab 1: Putar Bareng! → verifikasi animasi & hasil sinkron di Tab 2

---

## 📦 Dependency Baru

| Package | Alasan |
|---------|--------|
| `express` | HTTP server untuk Socket.IO |
| `socket.io` | WebSocket realtime, fallback polling, room support bawaan |
| `cors` | Izin cross-origin dari frontend domain |
| `nodemon` (dev) | Auto-restart saat development |

---

*Kamal Development Team — SpinDecide v2.0*
