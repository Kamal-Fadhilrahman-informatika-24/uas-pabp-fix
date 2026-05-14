// ============================================================
// spin.js - LOGIKA SPIN WHEEL
// ============================================================

let options = [];       // daftar pilihan user
let isSpinning = false; // mencegah double-spin
let currentAngle = 0;   // posisi roda saat ini

// Warna segmen roda — urut, akan diulang jika pilihan > 8
const COLORS = [
  '#FF6B6B', '#FFD93D', '#6BCB77', '#4D96FF',
  '#FF9A3C', '#C77DFF', '#00C9A7', '#F72585'
];

// ── Tambah pilihan ke daftar ─────────────────────────────────
function addOption() {
  const input = document.getElementById('optionInput');
  const text = input.value.trim();

  if (!text) {
    showToast('Masukkan teks pilihan dulu!', 'error');
    return;
  }
  if (options.length >= 12) {
    showToast('Maksimal 12 pilihan!', 'error');
    return;
  }
  if (options.includes(text)) {
    showToast('Pilihan sudah ada!', 'error');
    return;
  }

  options.push(text);
  input.value = '';
  input.focus();
  renderOptions();
  drawWheel();
}

// ── Hapus pilihan ────────────────────────────────────────────
function removeOption(index) {
  options.splice(index, 1);
  renderOptions();
  drawWheel();
}

// ── Tampilkan daftar pilihan di sidebar ──────────────────────
function renderOptions() {
  const list = document.getElementById('optionsList');
  const counter = document.getElementById('optionCount');

  counter.textContent = options.length;

  if (options.length === 0) {
    list.innerHTML = `
      <div class="empty-options">
        <span class="empty-icon">🎯</span>
        <p>Belum ada pilihan.<br>Tambahkan di atas!</p>
      </div>`;
    return;
  }

  list.innerHTML = options.map((opt, i) => `
    <div class="option-item" style="--color: ${COLORS[i % COLORS.length]}">
      <span class="option-dot"></span>
      <span class="option-text">${escapeHtml(opt)}</span>
      <button class="option-remove" onclick="removeOption(${i})" title="Hapus">✕</button>
    </div>
  `).join('');
}

// ── Gambar roda di canvas ─────────────────────────────────────
function drawWheel(highlightIndex = -1) {
  const canvas = document.getElementById('wheelCanvas');
  const ctx = canvas.getContext('2d');
  const size = canvas.width;
  const cx = size / 2;
  const cy = size / 2;
  const radius = cx - 10;

  ctx.clearRect(0, 0, size, size);

  if (options.length === 0) {
    // Tampilkan roda kosong
    ctx.beginPath();
    ctx.arc(cx, cy, radius, 0, Math.PI * 2);
    ctx.fillStyle = '#1e1e2e';
    ctx.fill();
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 3;
    ctx.stroke();

    ctx.fillStyle = '#555';
    ctx.font = 'bold 16px Sora, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Tambahkan pilihan', cx, cy - 10);
    ctx.fillText('untuk memulai!', cx, cy + 15);
    return;
  }

  const arc = (Math.PI * 2) / options.length;

  options.forEach((opt, i) => {
    const startAngle = arc * i + currentAngle;
    const endAngle = startAngle + arc;
    const color = COLORS[i % COLORS.length];
    const isHighlighted = i === highlightIndex;

    // Segmen
    ctx.beginPath();
    ctx.moveTo(cx, cy);
    ctx.arc(cx, cy, isHighlighted ? radius + 5 : radius, startAngle, endAngle);
    ctx.closePath();
    ctx.fillStyle = isHighlighted ? lightenColor(color, 30) : color;
    ctx.fill();
    ctx.strokeStyle = '#0f0f1a';
    ctx.lineWidth = 2;
    ctx.stroke();

    // Teks di segmen
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(startAngle + arc / 2);
    ctx.textAlign = 'right';
    ctx.fillStyle = '#fff';
    ctx.shadowColor = 'rgba(0,0,0,0.5)';
    ctx.shadowBlur = 3;
    
    const fontSize = options.length > 8 ? 11 : 13;
    ctx.font = `bold ${fontSize}px Sora, sans-serif`;
    
    // Potong teks jika terlalu panjang
    let label = opt;
    if (label.length > 14) label = label.substring(0, 12) + '…';
    
    ctx.fillText(label, radius - 15, 5);
    ctx.restore();
  });

  // Lingkaran tengah
  ctx.beginPath();
  ctx.arc(cx, cy, 22, 0, Math.PI * 2);
  ctx.fillStyle = '#0f0f1a';
  ctx.fill();
  ctx.strokeStyle = '#fff';
  ctx.lineWidth = 3;
  ctx.stroke();

  // Logo/ikon tengah
  ctx.fillStyle = '#fff';
  ctx.font = 'bold 16px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('🎯', cx, cy);
}

// ── SPIN! ─────────────────────────────────────────────────────
async function spinWheel() {
  if (isSpinning) return;
  if (options.length < 2) {
    showToast('Tambahkan minimal 2 pilihan!', 'error');
    return;
  }

  isSpinning = true;
  document.getElementById('spinBtn').disabled = true;
  document.getElementById('spinBtn').textContent = '🌀 Berputar...';

  // ── Spin SFX ──────────────────────────────────────────────
  if (window.AudioController) AudioController.playSpinSound();

  // Animasi spin
  const totalRotation = (Math.PI * 2 * (5 + Math.random() * 5));   // 5–10 putaran
  const duration = 4000 + Math.random() * 1000;  // 4–5 detik
  const startAngle = currentAngle;
  const startTime = performance.now();

  function easeOut(t) {
    return 1 - Math.pow(1 - t, 4); // ease-out quartic
  }

  function animate(now) {
    const elapsed = now - startTime;
    const progress = Math.min(elapsed / duration, 1);
    const eased = easeOut(progress);

    currentAngle = startAngle + totalRotation * eased;
    drawWheel();

    if (progress < 1) {
      requestAnimationFrame(animate);
    } else {
      // Hitung hasil
      const arc = (Math.PI * 2) / options.length;
      // Penunjuk ada di kanan (angle 0), normalisasi
      const normalizedAngle = ((currentAngle % (Math.PI * 2)) + Math.PI * 2) % (Math.PI * 2);
      const pointerAngle = (Math.PI * 2 - normalizedAngle) % (Math.PI * 2);
      const winnerIndex = Math.floor(pointerAngle / arc) % options.length;
      const winner = options[winnerIndex];

      drawWheel(winnerIndex); // highlight pemenang
      // ── Stop Spin SFX ──────────────────────────────────────────────
      if (window.AudioController) AudioController.stopSpinSound();
      showResult(winner);
      saveSpinResult(winner);

      isSpinning = false;
      document.getElementById('spinBtn').disabled = false;
      document.getElementById('spinBtn').textContent = '🎰 PUTAR!';
    }
  }

  requestAnimationFrame(animate);
}

// ── Tampilkan hasil ───────────────────────────────────────────
function showResult(winner) {
  const overlay = document.getElementById('resultOverlay');
  const resultText = document.getElementById('resultText');

  resultText.textContent = winner;
  overlay.classList.add('visible');

  // Confetti effect
  launchConfetti();
}

function closeResult() {
  document.getElementById('resultOverlay').classList.remove('visible');
}

// ── Simpan hasil ke Supabase ──────────────────────────────────
async function saveSpinResult(result) {
  try {
    const user = await getCurrentUser();
    if (!user) return;

    const { error } = await supabaseClient
      .from('spins')
      .insert({
        user_id: user.id,
        options: options,       // array of strings
        result: result,
        created_at: new Date().toISOString()
      });

    if (error) {
      console.error('Gagal menyimpan:', error.message);
    } else {
      showToast('Hasil tersimpan! ✓', 'success');
    }
  } catch (err) {
    console.error('Error saat menyimpan:', err);
  }
}

// ── Input Enter key ───────────────────────────────────────────
function handleInputKey(e) {
  if (e.key === 'Enter') addOption();
}

// ── Confetti sederhana ────────────────────────────────────────
function launchConfetti() {
  const colors = ['#FF6B6B', '#FFD93D', '#6BCB77', '#4D96FF', '#C77DFF'];
  const container = document.body;

  for (let i = 0; i < 60; i++) {
    const dot = document.createElement('div');
    dot.className = 'confetti-dot';
    dot.style.cssText = `
      left: ${Math.random() * 100}vw;
      background: ${colors[Math.floor(Math.random() * colors.length)]};
      animation-delay: ${Math.random() * 0.5}s;
      width: ${4 + Math.random() * 8}px;
      height: ${4 + Math.random() * 8}px;
      border-radius: ${Math.random() > 0.5 ? '50%' : '2px'};
    `;
    container.appendChild(dot);
    setTimeout(() => dot.remove(), 2500);
  }
}

// ── Utility ───────────────────────────────────────────────────
function escapeHtml(text) {
  const div = document.createElement('div');
  div.appendChild(document.createTextNode(text));
  return div.innerHTML;
}

function lightenColor(hex, amount) {
  const num = parseInt(hex.replace('#', ''), 16);
  const r = Math.min(255, (num >> 16) + amount);
  const g = Math.min(255, ((num >> 8) & 0xff) + amount);
  const b = Math.min(255, (num & 0xff) + amount);
  return `rgb(${r},${g},${b})`;
}

function showToast(msg, type = 'info') {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.className = `toast toast-${type} visible`;
  setTimeout(() => toast.classList.remove('visible'), 3000);
}

// ── Resize canvas responsif ────────────────────────────────────
function resizeCanvas() {
  const canvas = document.getElementById('wheelCanvas');
  const container = document.getElementById('wheelContainer');
  if (!canvas || !container) return;

  const size = Math.min(container.offsetWidth, container.offsetHeight, 420);
  canvas.width = size;
  canvas.height = size;
  drawWheel();
}
