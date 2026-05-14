// ============================================================
// truth-dare.js — LOGIKA TRUTH OR DARE
// ============================================================

// ── State ────────────────────────────────────────────────────
let currentMode = null;         // 'truth' | 'dare' | null
let currentIndex = -1;          // index kartu saat ini
let shuffledTruths = [];
let shuffledDares = [];
let players = [];               // array nama pemain
let currentPlayerIndex = 0;     // giliran pemain saat ini
let stats = { truth: 0, dare: 0 };

// ── Inisialisasi & load saved state ──────────────────────────
function initTD() {
  const saved = localStorage.getItem('td_stats');
  if (saved) {
    try {
      stats = JSON.parse(saved);
      updateStats();
    } catch (_) {}
  }

  const savedPlayers = localStorage.getItem('td_players');
  if (savedPlayers) {
    try {
      players = JSON.parse(savedPlayers);
      renderPlayers();
    } catch (_) {}
  }

  shuffledTruths = shuffle([...TRUTH_QUESTIONS]);
  shuffledDares  = shuffle([...DARE_CHALLENGES]);
}

// ── Pilih Mode ────────────────────────────────────────────────
function selectMode(mode) {
  currentMode = mode;

  // Update button state
  document.getElementById('truthBtn').classList.toggle('active', mode === 'truth');
  document.getElementById('dareBtn').classList.toggle('active', mode === 'dare');

  // Reset index & show card
  currentIndex = -1;
  showCard();
  nextCard();
}

// ── Tampilkan area kartu ──────────────────────────────────────
function showCard() {
  document.getElementById('tdIdle').style.display = 'none';
  const card = document.getElementById('tdCard');
  card.style.display = 'block';

  // Apply mode class
  card.classList.remove('truth-mode', 'dare-mode');
  card.classList.add(currentMode + '-mode');

  // Badge & icon
  if (currentMode === 'truth') {
    document.getElementById('tdCardBadge').textContent = '🧠 TRUTH';
    document.getElementById('tdCardIcon').textContent  = '🧠';
  } else {
    document.getElementById('tdCardBadge').textContent = '🔥 DARE';
    document.getElementById('tdCardIcon').textContent  = '🔥';
  }
}

// ── Kartu berikutnya (random) ─────────────────────────────────
function nextCard() {
  if (!currentMode) return;

  const pool = currentMode === 'truth' ? shuffledTruths : shuffledDares;

  // Advance index, reshuffle bila habis
  currentIndex++;
  if (currentIndex >= pool.length) {
    reshuffle();
    currentIndex = 0;
    showToast('Semua kartu sudah diputar, diacak ulang! ♻️', 'info');
  }

  const text = pool[currentIndex];

  // Animate icon bounce
  const icon = document.getElementById('tdCardIcon');
  icon.style.animation = 'none';
  void icon.offsetWidth; // reflow
  icon.style.animation = 'tdIconBounce 0.5s cubic-bezier(0.34, 1.56, 0.64, 1)';

  // Animate text
  const textEl = document.getElementById('tdCardText');
  textEl.style.animation = 'none';
  void textEl.offsetWidth;
  textEl.style.animation = 'tdTextIn 0.3s ease 0.1s both';
  textEl.textContent = text;

  // Counter
  document.getElementById('tdCardCounter').textContent =
    `${currentIndex + 1} / ${pool.length}`;

  // Progress bar
  const pct = ((currentIndex + 1) / pool.length) * 100;
  document.getElementById('tdProgressFill').style.width = pct + '%';

  // Update stats
  stats[currentMode]++;
  saveStats();
  updateStats();

  // Advance player turn
  advancePlayer();

  // Confetti ringan untuk dare
  if (currentMode === 'dare') launchMiniConfetti();
}

// ── Kembali ke selector ───────────────────────────────────────
function backToSelect() {
  currentMode = null;
  document.getElementById('tdIdle').style.display = 'block';
  document.getElementById('tdCard').style.display = 'none';
  document.getElementById('truthBtn').classList.remove('active');
  document.getElementById('dareBtn').classList.remove('active');
}

// ── Reshuffle deck ────────────────────────────────────────────
function reshuffle() {
  shuffledTruths = shuffle([...TRUTH_QUESTIONS]);
  shuffledDares  = shuffle([...DARE_CHALLENGES]);
}

// ── Player management ─────────────────────────────────────────
function showAddPlayer() {
  document.getElementById('addPlayerForm').style.display = 'flex';
  document.getElementById('playerNameInput').focus();
}

function hideAddPlayer() {
  document.getElementById('addPlayerForm').style.display = 'none';
  document.getElementById('playerNameInput').value = '';
}

function addPlayer() {
  const input = document.getElementById('playerNameInput');
  const name = input.value.trim();
  if (!name) return;
  if (players.includes(name)) {
    showToast('Nama sudah ada!', 'error');
    return;
  }
  players.push(name);
  savePlayers();
  renderPlayers();
  hideAddPlayer();
  showToast(`${name} ditambahkan! ✓`, 'success');
}

function removePlayer(index) {
  players.splice(index, 1);
  if (currentPlayerIndex >= players.length) currentPlayerIndex = 0;
  savePlayers();
  renderPlayers();
}

function handlePlayerKey(e) {
  if (e.key === 'Enter') addPlayer();
  if (e.key === 'Escape') hideAddPlayer();
}

function advancePlayer() {
  if (players.length === 0) return;
  currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
  renderPlayers();
}

function renderPlayers() {
  const list = document.getElementById('tdPlayersList');
  if (players.length === 0) {
    list.innerHTML = '<div class="td-no-players"><span>Tambahkan nama pemain untuk track giliran!</span></div>';
    return;
  }

  list.innerHTML = players.map((name, i) => `
    <div class="td-player-chip ${i === currentPlayerIndex ? 'active-turn' : ''}">
      <div class="td-player-avatar">${name.charAt(0).toUpperCase()}</div>
      <span>${escapeHtml(name)}</span>
      ${i === currentPlayerIndex ? '<span style="font-size:0.75rem;margin-left:2px">👑</span>' : ''}
      <button class="td-player-remove" onclick="removePlayer(${i})" title="Hapus">✕</button>
    </div>
  `).join('');
}

// ── Stats ─────────────────────────────────────────────────────
function updateStats() {
  document.getElementById('statTruthCount').textContent = stats.truth;
  document.getElementById('statDareCount').textContent  = stats.dare;
  document.getElementById('statTotalCount').textContent = stats.truth + stats.dare;
}

function resetStats() {
  stats = { truth: 0, dare: 0 };
  saveStats();
  updateStats();
  showToast('Statistik direset!', 'info');
}

function saveStats() {
  localStorage.setItem('td_stats', JSON.stringify(stats));
}

function savePlayers() {
  localStorage.setItem('td_players', JSON.stringify(players));
}

// ── Confetti ringan (khusus DARE) ────────────────────────────
function launchMiniConfetti() {
  const colors = ['#FF6B6B', '#FFD93D', '#FF9A3C'];
  for (let i = 0; i < 20; i++) {
    const dot = document.createElement('div');
    dot.className = 'confetti-dot';
    dot.style.cssText = `
      left: ${Math.random() * 100}vw;
      background: ${colors[Math.floor(Math.random() * colors.length)]};
      animation-delay: ${Math.random() * 0.3}s;
      width: ${4 + Math.random() * 6}px;
      height: ${4 + Math.random() * 6}px;
      border-radius: ${Math.random() > 0.5 ? '50%' : '2px'};
    `;
    document.body.appendChild(dot);
    setTimeout(() => dot.remove(), 2500);
  }
}

// ── Utilities ─────────────────────────────────────────────────
function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.appendChild(document.createTextNode(text));
  return div.innerHTML;
}

function showToast(msg, type = 'info') {
  const toast = document.getElementById('toast');
  toast.textContent = msg;
  toast.className = `toast toast-${type} visible`;
  setTimeout(() => toast.classList.remove('visible'), 3000);
}

// ── Auto-init ─────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', initTD);
