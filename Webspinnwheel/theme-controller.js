// ============================================================
// theme-controller.js - DARK MODE / LIGHT MODE CONTROLLER
// SpinDecide — Global Theme System
//
// Cara kerja:
// 1. Membaca preferensi dari localStorage ('spindecide_theme')
// 2. Default: 'dark' (sesuai desain asli)
// 3. Mengubah attribute [data-theme] pada <html>
// 4. CSS di global-features.css menangani semua variabel warna
// 5. Toggle button dirender di semua halaman secara otomatis
// ============================================================

(function ThemeController() {
  const STORAGE_KEY = 'spindecide_theme';
  const DEFAULT_THEME = 'dark'; // sesuai desain asli

  // ── Inisialisasi: terapkan tema sebelum render (cegah flash) ──
  function getStoredTheme() {
    try {
      return localStorage.getItem(STORAGE_KEY) || DEFAULT_THEME;
    } catch (e) {
      return DEFAULT_THEME;
    }
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    // Update meta theme-color untuk browser UI
    const metaTheme = document.querySelector('meta[name="theme-color"]');
    if (metaTheme) {
      metaTheme.content = theme === 'dark' ? '#0f0f1a' : '#f5f5fa';
    }
  }

  function saveTheme(theme) {
    try {
      localStorage.setItem(STORAGE_KEY, theme);
    } catch (e) { /* storage not available */ }
  }

  function toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || DEFAULT_THEME;
    const next = current === 'dark' ? 'light' : 'dark';
    applyTheme(next);
    saveTheme(next);
    updateToggleButton(next);
  }

  function updateToggleButton(theme) {
    const btn = document.getElementById('themeToggleBtn');
    if (!btn) return;
    if (theme === 'dark') {
      btn.innerHTML = '☀️';
      btn.setAttribute('title', 'Ganti ke Mode Terang');
      btn.setAttribute('aria-label', 'Aktifkan mode terang');
    } else {
      btn.innerHTML = '🌙';
      btn.setAttribute('title', 'Ganti ke Mode Gelap');
      btn.setAttribute('aria-label', 'Aktifkan mode gelap');
    }
  }

  // ── Inject tombol ke navbar (jika ada) ──────────────────────
  function injectToggleButton() {
    // Cek apakah tombol sudah ada
    if (document.getElementById('themeToggleBtn')) return;

    const navUser = document.querySelector('.nav-user');
    const authCard = document.querySelector('.auth-card');

    if (navUser) {
      // Halaman dengan navbar: tambahkan sebelum logout button
      const btn = document.createElement('button');
      btn.id = 'themeToggleBtn';
      btn.className = 'btn-theme-toggle';
      btn.onclick = toggleTheme;
      navUser.insertBefore(btn, navUser.firstChild);
    } else if (authCard) {
      // Halaman login/register: tambahkan pojok kanan atas
      const btn = document.createElement('button');
      btn.id = 'themeToggleBtn';
      btn.className = 'btn-theme-toggle btn-theme-toggle--floating';
      btn.onclick = toggleTheme;
      document.body.appendChild(btn);
    } else {
      // Fallback: floating button
      const btn = document.createElement('button');
      btn.id = 'themeToggleBtn';
      btn.className = 'btn-theme-toggle btn-theme-toggle--floating';
      btn.onclick = toggleTheme;
      document.body.appendChild(btn);
    }

    updateToggleButton(getStoredTheme());
  }

  // ── Jalankan saat DOM siap ────────────────────────────────
  // Terapkan tema langsung (sebelum DOMContentLoaded agar tidak flash)
  applyTheme(getStoredTheme());

  // Inject button saat DOM siap
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', injectToggleButton);
  } else {
    injectToggleButton();
  }

  // ── Expose ke global ──────────────────────────────────────
  window.ThemeController = { toggle: toggleTheme, get: getStoredTheme, apply: applyTheme };

})();
