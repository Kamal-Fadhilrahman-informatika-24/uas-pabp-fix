// ============================================================
// history.js - RIWAYAT SPIN
// ============================================================

let allHistory = [];
let currentFilter = 'all';

// ── Muat riwayat dari Supabase ────────────────────────────────
async function loadHistory() {
  const loadingEl = document.getElementById('historyLoading');
  const listEl = document.getElementById('historyList');

  loadingEl.style.display = 'flex';
  listEl.innerHTML = '';

  try {
    const user = await getCurrentUser();
    if (!user) return;

    const { data, error } = await supabaseClient
      .from('spins')
      .select('*')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false })
      .limit(100);

    if (error) throw error;

    allHistory = data || [];
    renderHistory(allHistory);
    renderStats(allHistory);

  } catch (err) {
    listEl.innerHTML = `<div class="history-error">Gagal memuat riwayat: ${err.message}</div>`;
  } finally {
    loadingEl.style.display = 'none';
  }
}

// ── Tampilkan daftar riwayat ──────────────────────────────────
function renderHistory(data) {
  const listEl = document.getElementById('historyList');
  const countEl = document.getElementById('historyCount');

  countEl.textContent = data.length;

  if (data.length === 0) {
    listEl.innerHTML = `
      <div class="empty-history">
        <div class="empty-icon">🎯</div>
        <h3>Belum ada riwayat</h3>
        <p>Kembali ke dashboard dan mulai putar roda!</p>
        <a href="dashboard.html" class="btn-primary">Ke Dashboard</a>
      </div>`;
    return;
  }

  listEl.innerHTML = data.map((spin, idx) => {
    const date = new Date(spin.created_at);
    const dateStr = date.toLocaleDateString('id-ID', {
      day: '2-digit', month: 'long', year: 'numeric'
    });
    const timeStr = date.toLocaleTimeString('id-ID', {
      hour: '2-digit', minute: '2-digit'
    });

    const optionsPreview = spin.options.slice(0, 4).join(', ')
      + (spin.options.length > 4 ? ` +${spin.options.length - 4} lagi` : '');

    return `
      <div class="history-card" id="history-card-${spin.id}" style="animation-delay: ${idx * 0.05}s">
        <div class="history-card-header">
          <div class="history-result">
            <span class="result-badge">🏆 ${escapeHtml(spin.result)}</span>
          </div>
          <div class="history-card-actions">
            <div class="history-time">
              <span class="history-date">${dateStr}</span>
              <span class="history-hour">${timeStr}</span>
            </div>
            <button
              class="btn-delete-item"
              title="Hapus riwayat ini"
              onclick="confirmDeleteItem('${spin.id}')"
              aria-label="Hapus riwayat ini"
            >🗑️</button>
          </div>
        </div>
        <div class="history-options">
          <span class="options-label">Pilihan (${spin.options.length}):</span>
          <span class="options-text">${escapeHtml(optionsPreview)}</span>
        </div>
        <button class="btn-detail" onclick="showDetail(${idx})">Lihat Detail</button>
      </div>
    `;
  }).join('');
}

// ── Statistik ─────────────────────────────────────────────────
function renderStats(data) {
  document.getElementById('statTotal').textContent = data.length;

  if (data.length === 0) {
    document.getElementById('statTopResult').textContent = '–';
    document.getElementById('statAvgOptions').textContent = '–';
    return;
  }

  const freq = {};
  data.forEach(s => freq[s.result] = (freq[s.result] || 0) + 1);
  const topResult = Object.entries(freq).sort((a, b) => b[1] - a[1])[0];
  document.getElementById('statTopResult').textContent = topResult ? topResult[0] : '-';

  const avgOptions = data.reduce((sum, s) => sum + s.options.length, 0) / data.length;
  document.getElementById('statAvgOptions').textContent = avgOptions.toFixed(1);
}

// ── Detail spin ───────────────────────────────────────────────
function showDetail(idx) {
  const filtered = getFilteredData();
  const spin = filtered[idx];
  if (!spin) return;

  const date = new Date(spin.created_at).toLocaleString('id-ID');
  const modal = document.getElementById('detailModal');

  document.getElementById('detailResult').textContent = spin.result;
  document.getElementById('detailDate').textContent = date;
  document.getElementById('detailOptions').innerHTML = spin.options
    .map(opt => `<span class="detail-option ${opt === spin.result ? 'winner' : ''}">${escapeHtml(opt)}</span>`)
    .join('');

  modal.classList.add('visible');
}

function closeDetail() {
  document.getElementById('detailModal').classList.remove('visible');
}

// ── Filter ────────────────────────────────────────────────────
function filterHistory(filter) {
  currentFilter = filter;
  document.querySelectorAll('.filter-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.filter === filter);
  });
  renderHistory(getFilteredData());
}

function getFilteredData() {
  const now = new Date();
  return allHistory.filter(spin => {
    const date = new Date(spin.created_at);
    if (currentFilter === 'today') {
      return date.toDateString() === now.toDateString();
    }
    if (currentFilter === 'week') {
      const weekAgo = new Date(now - 7 * 24 * 60 * 60 * 1000);
      return date >= weekAgo;
    }
    return true;
  });
}

// ── Search ────────────────────────────────────────────────────
function searchHistory(query) {
  const q = query.toLowerCase();
  const filtered = allHistory.filter(spin =>
    spin.result.toLowerCase().includes(q) ||
    spin.options.some(opt => opt.toLowerCase().includes(q))
  );
  renderHistory(filtered);
}

// ── Utility ───────────────────────────────────────────────────
function escapeHtml(text) {
  const div = document.createElement('div');
  div.appendChild(document.createTextNode(text));
  return div.innerHTML;
}

// ============================================================
// FITUR DELETE HISTORY
// ============================================================

// ── Tampilkan modal konfirmasi hapus semua ─────────────────────
function confirmDeleteAll() {
  if (allHistory.length === 0) {
    showToast('Tidak ada riwayat untuk dihapus.', 'error');
    return;
  }
  document.getElementById('deleteAllModal').classList.add('visible');
}

// ── Tutup modal konfirmasi hapus semua ────────────────────────
function closeDeleteAllModal() {
  document.getElementById('deleteAllModal').classList.remove('visible');
}

// ── Hapus semua riwayat milik user ────────────────────────────
async function deleteAllHistory() {
  const btn = document.getElementById('btnConfirmDeleteAll');
  btn.disabled = true;
  btn.textContent = 'Menghapus…';

  try {
    const user = await getCurrentUser();
    if (!user) throw new Error('User tidak ditemukan. Silakan login ulang.');

    console.log('[DELETE ALL] Memulai penghapusan semua history untuk user:', user.id);
    console.log('[DELETE ALL] Jumlah data sebelum hapus:', allHistory.length);

    // ── Query DELETE ke Supabase dengan .select() untuk verifikasi baris terhapus
    const { data: deletedRows, error } = await supabaseClient
      .from('spins')
      .delete()
      .eq('user_id', user.id)
      .select();  // ← wajib: mengembalikan baris yang benar-benar terhapus dari DB

    // ── Log hasil dari database
    console.log('[DELETE ALL] Response dari DB:', { deletedRows, error });

    if (error) {
      console.error('[DELETE ALL] DB Error:', error.code, error.message, error.details);
      throw new Error(error.message);
    }

    const jumlahTerhapus = deletedRows ? deletedRows.length : 0;
    console.log('[DELETE ALL] Baris yang benar-benar terhapus dari DB:', jumlahTerhapus);

    // ── Verifikasi: jika 0 row terhapus padahal ada data → kemungkinan RLS memblokir
    if (jumlahTerhapus === 0 && allHistory.length > 0) {
      console.warn('[DELETE ALL] PERINGATAN: Query berhasil tapi 0 row terhapus!');
      console.warn('[DELETE ALL] Kemungkinan penyebab: RLS policy DELETE belum dibuat di Supabase.');
      console.warn('[DELETE ALL] Buka Supabase Dashboard → Table Editor → spins → Policies → Tambah DELETE policy.');
      throw new Error(
        'Penghapusan gagal: tidak ada data yang terhapus dari database. ' +
        'Kemungkinan RLS policy DELETE belum diaktifkan. Lihat console untuk detail.'
      );
    }

    // ── Re-fetch dari DB untuk konfirmasi data benar-benar sudah hilang
    console.log('[DELETE ALL] Re-fetch dari DB untuk konfirmasi…');
    const { data: checkData, error: checkError } = await supabaseClient
      .from('spins')
      .select('id')
      .eq('user_id', user.id);

    if (!checkError) {
      console.log('[DELETE ALL] Sisa data di DB setelah delete:', checkData ? checkData.length : 'error');
    }

    // ── Update local state & UI hanya setelah DB konfirmasi berhasil
    allHistory = [];
    closeDeleteAllModal();
    renderHistory([]);
    renderStats([]);

    showToast(`${jumlahTerhapus} riwayat berhasil dihapus permanen.`, 'success');
    console.log('[DELETE ALL] Selesai. UI diperbarui.');

  } catch (err) {
    console.error('[DELETE ALL] Gagal:', err.message);
    showToast('Gagal menghapus: ' + err.message, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = 'Ya, Hapus Semua';
  }
}

// ── Tampilkan modal konfirmasi hapus 1 item ────────────────────
function confirmDeleteItem(spinId) {
  const modal = document.getElementById('deleteItemModal');
  modal.dataset.spinId = spinId;
  modal.classList.add('visible');
}

// ── Tutup modal konfirmasi hapus 1 item ───────────────────────
function closeDeleteItemModal() {
  const modal = document.getElementById('deleteItemModal');
  modal.dataset.spinId = '';
  modal.classList.remove('visible');
}

// ── Hapus 1 item riwayat berdasarkan ID ───────────────────────
async function deleteHistoryItem() {
  const modal = document.getElementById('deleteItemModal');
  const spinId = modal.dataset.spinId;
  if (!spinId) return;

  const btn = document.getElementById('btnConfirmDeleteItem');
  btn.disabled = true;
  btn.textContent = 'Menghapus…';

  try {
    const user = await getCurrentUser();
    if (!user) throw new Error('User tidak ditemukan. Silakan login ulang.');

    console.log('[DELETE ITEM] Memulai penghapusan spin ID:', spinId);
    console.log('[DELETE ITEM] User ID:', user.id);

    // ── Query DELETE ke Supabase dengan validasi ownership + .select() untuk verifikasi
    const { data: deletedRows, error } = await supabaseClient
      .from('spins')
      .delete()
      .eq('id', spinId)          // ← filter by primary key
      .eq('user_id', user.id)    // ← validasi ownership: hanya bisa hapus milik sendiri
      .select();                 // ← wajib: mengembalikan baris yang benar-benar terhapus

    // ── Log hasil dari database
    console.log('[DELETE ITEM] Response dari DB:', { deletedRows, error });

    if (error) {
      console.error('[DELETE ITEM] DB Error:', error.code, error.message, error.details);
      throw new Error(error.message);
    }

    const jumlahTerhapus = deletedRows ? deletedRows.length : 0;
    console.log('[DELETE ITEM] Baris yang benar-benar terhapus dari DB:', jumlahTerhapus);

    // ── Verifikasi: jika 0 row terhapus → RLS memblokir atau ID tidak cocok
    if (jumlahTerhapus === 0) {
      console.warn('[DELETE ITEM] PERINGATAN: 0 row terhapus dari DB!');
      console.warn('[DELETE ITEM] spin ID yang dicoba dihapus:', spinId);
      console.warn('[DELETE ITEM] Kemungkinan penyebab:');
      console.warn('  1. RLS policy DELETE belum dibuat di Supabase → tambahkan policy');
      console.warn('  2. spin ID tidak ditemukan / bukan milik user ini');
      throw new Error(
        'Penghapusan gagal: data tidak terhapus dari database. ' +
        'Kemungkinan RLS policy DELETE belum diaktifkan. Lihat console untuk detail.'
      );
    }

    // ── Update local state hanya setelah DB berhasil hapus
    allHistory = allHistory.filter(s => String(s.id) !== String(spinId));

    // ── Tutup modal
    closeDeleteItemModal();

    // ── Animasi hilang & hapus card dari DOM secara realtime
    const card = document.getElementById('history-card-' + spinId);
    if (card) {
      card.style.transition = 'opacity 0.3s, transform 0.3s';
      card.style.opacity = '0';
      card.style.transform = 'translateX(20px)';
      setTimeout(() => {
        card.remove();
        renderStats(allHistory);
        document.getElementById('historyCount').textContent = getFilteredData().length;
        if (allHistory.length === 0) renderHistory([]);
      }, 300);
    }

    showToast('Riwayat berhasil dihapus permanen.', 'success');
    console.log('[DELETE ITEM] Selesai. Item dihapus dari DB dan UI.');

  } catch (err) {
    console.error('[DELETE ITEM] Gagal:', err.message);
    showToast('Gagal menghapus: ' + err.message, 'error');
  } finally {
    btn.disabled = false;
    btn.textContent = 'Ya, Hapus';
  }
}

// ── Toast Notification ────────────────────────────────────────
function showToast(message, type = 'success') {
  const toast = document.getElementById('toast');
  toast.textContent = message;
  toast.className = 'toast toast-' + type + ' visible';
  setTimeout(() => {
    toast.className = 'toast';
  }, 3000);
}
