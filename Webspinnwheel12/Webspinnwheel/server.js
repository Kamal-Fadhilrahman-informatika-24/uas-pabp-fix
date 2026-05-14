// ============================================================
// server.js — BACKEND REALTIME SOCKET.IO
// SpinDecide Multiplayer Server
// Run: node server.js
// ============================================================

const express    = require('express');
const http       = require('http');
const { Server } = require('socket.io');
const cors       = require('cors');

const app    = express();
const server = http.createServer(app);

// ── CORS ──────────────────────────────────────────────────────
// Ganti origin dengan domain frontend kamu saat deploy
const ALLOWED_ORIGINS = [
  'http://localhost:5500',
  'http://127.0.0.1:5500',
  'http://localhost:3000',
  'https://spindecide.vercel.app',   // ← ganti dengan URL Vercel kamu
  'https://spindecide.netlify.app',  // ← ganti dengan URL Netlify kamu
];

app.use(cors({ origin: ALLOWED_ORIGINS, credentials: true }));

const io = new Server(server, {
  cors: {
    origin: ALLOWED_ORIGINS,
    methods: ['GET', 'POST'],
    credentials: true,
  },
  pingTimeout: 30000,
  pingInterval: 10000,
});

// ── In-Memory Room Store ──────────────────────────────────────
// Structure: { [roomCode]: { players: [], options: [], hostId: '' } }
const rooms = new Map();

// ── Utilities ─────────────────────────────────────────────────
function generateRoomCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no O,0,I,1 (ambiguous)
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  // Pastikan unik
  return rooms.has(code) ? generateRoomCode() : code;
}

function getPlayerBySocket(socketId) {
  for (const [code, room] of rooms) {
    const player = room.players.find(p => p.socketId === socketId);
    if (player) return { room, code, player };
  }
  return null;
}

function sanitize(str, maxLen = 40) {
  return String(str || '').trim().substring(0, maxLen);
}

// ── Health Check ──────────────────────────────────────────────
app.get('/', (req, res) => {
  res.json({
    status: 'ok',
    service: 'SpinDecide Realtime Server',
    rooms: rooms.size,
    timestamp: new Date().toISOString(),
  });
});

app.get('/rooms', (req, res) => {
  const summary = [];
  for (const [code, room] of rooms) {
    summary.push({
      code,
      players: room.players.length,
      options: room.options.length,
    });
  }
  res.json(summary);
});

// ── Socket.IO Events ──────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`[+] Connected: ${socket.id}`);

  // ── Create Room ────────────────────────────────────────────
  socket.on('room:create', ({ name }) => {
    const playerName = sanitize(name, 20);
    if (!playerName) {
      socket.emit('error', { message: 'Nama tidak boleh kosong!' });
      return;
    }

    const roomCode = generateRoomCode();
    const player   = { socketId: socket.id, name: playerName, isHost: true };

    rooms.set(roomCode, {
      players: [player],
      options: [],
      hostId:  socket.id,
      createdAt: Date.now(),
    });

    socket.join(roomCode);

    socket.emit('room:joined', {
      roomCode,
      players: rooms.get(roomCode).players,
      options: [],
      isHost:  true,
    });

    console.log(`[ROOM] Created: ${roomCode} by ${playerName}`);
  });

  // ── Join Room ───────────────────────────────────────────────
  socket.on('room:join', ({ name, roomCode }) => {
    const playerName = sanitize(name, 20);
    const code       = sanitize(roomCode, 6).toUpperCase();

    if (!playerName) {
      socket.emit('error', { message: 'Nama tidak boleh kosong!' });
      return;
    }

    if (!rooms.has(code)) {
      socket.emit('error', { message: `Room ${code} tidak ditemukan!` });
      return;
    }

    const room = rooms.get(code);

    if (room.players.length >= 10) {
      socket.emit('error', { message: 'Room sudah penuh (maksimal 10 pemain)!' });
      return;
    }

    // Cek nama duplikat
    const nameTaken = room.players.some(p => p.name.toLowerCase() === playerName.toLowerCase());
    if (nameTaken) {
      socket.emit('error', { message: 'Nama sudah dipakai di room ini!' });
      return;
    }

    const player = { socketId: socket.id, name: playerName, isHost: false };
    room.players.push(player);
    socket.join(code);

    // Kirim ke player yang baru masuk
    socket.emit('room:joined', {
      roomCode: code,
      players:  room.players,
      options:  room.options,
      isHost:   false,
    });

    // Broadcast ke pemain lain
    socket.to(code).emit('room:playerJoined', {
      player,
      players: room.players,
    });

    console.log(`[ROOM] ${playerName} joined ${code} (${room.players.length} players)`);
  });

  // ── Leave Room ──────────────────────────────────────────────
  socket.on('room:leave', ({ roomCode }) => {
    handlePlayerLeave(socket, roomCode);
  });

  // ── Update Options (Host only) ──────────────────────────────
  socket.on('room:updateOptions', ({ roomCode, options }) => {
    const code = sanitize(roomCode, 6).toUpperCase();
    if (!rooms.has(code)) return;

    const room = rooms.get(code);
    if (room.hostId !== socket.id) return; // Only host

    // Validasi & sanitize options
    const cleanOptions = (Array.isArray(options) ? options : [])
      .map(o => sanitize(o, 40))
      .filter(Boolean)
      .slice(0, 12);

    room.options = cleanOptions;

    // Broadcast ke semua (termasuk host)
    io.to(code).emit('room:optionsUpdated', { options: cleanOptions });
  });

  // ── Spin Start (Host only) ──────────────────────────────────
  socket.on('spin:start', ({ roomCode, totalRotation, duration, startAngle }) => {
    const code = sanitize(roomCode, 6).toUpperCase();
    if (!rooms.has(code)) return;

    const room = rooms.get(code);
    if (room.hostId !== socket.id) return; // Only host can start spin

    if (room.options.length < 2) {
      socket.emit('error', { message: 'Minimal 2 pilihan untuk spin!' });
      return;
    }

    // Broadcast ke SEMUA pemain di room (termasuk host)
    io.to(code).emit('spin:start', {
      totalRotation: Number(totalRotation),
      duration:      Number(duration),
      startAngle:    Number(startAngle),
    });

    console.log(`[SPIN] Room ${code} spinning (${room.options.length} options)`);
  });

  // ── Spin Result (Host only) ─────────────────────────────────
  socket.on('spin:result', ({ roomCode, winner, winnerIndex, spunBy }) => {
    const code = sanitize(roomCode, 6).toUpperCase();
    if (!rooms.has(code)) return;

    const room = rooms.get(code);
    if (room.hostId !== socket.id) return;

    // Broadcast hasil ke semua
    io.to(code).emit('spin:result', {
      winner:      sanitize(winner, 40),
      winnerIndex: Number(winnerIndex),
      spunBy:      sanitize(spunBy, 20),
    });

    console.log(`[SPIN] Result in ${code}: "${winner}" (by ${spunBy})`);
  });

  // ── Disconnect ──────────────────────────────────────────────
  socket.on('disconnect', () => {
    console.log(`[-] Disconnected: ${socket.id}`);
    // Cari room yang diikuti socket ini
    for (const [code] of rooms) {
      const room = rooms.get(code);
      if (room && room.players.some(p => p.socketId === socket.id)) {
        handlePlayerLeave(socket, code);
        break;
      }
    }
  });
});

// ── Handle Player Leave ───────────────────────────────────────
function handlePlayerLeave(socket, roomCode) {
  const code = String(roomCode || '').toUpperCase();
  if (!rooms.has(code)) return;

  const room       = rooms.get(code);
  const playerIdx  = room.players.findIndex(p => p.socketId === socket.id);
  if (playerIdx === -1) return;

  const [leavingPlayer] = room.players.splice(playerIdx, 1);
  socket.leave(code);

  console.log(`[ROOM] ${leavingPlayer.name} left ${code} (${room.players.length} remaining)`);

  // Kalau room kosong, hapus
  if (room.players.length === 0) {
    rooms.delete(code);
    console.log(`[ROOM] Deleted empty room: ${code}`);
    return;
  }

  // Kalau host yang keluar, assign host baru
  let newHost = null;
  if (room.hostId === socket.id && room.players.length > 0) {
    room.players[0].isHost = true;
    room.hostId = room.players[0].socketId;
    newHost = room.players[0].socketId;
    console.log(`[ROOM] New host in ${code}: ${room.players[0].name}`);
  }

  // Broadcast ke yang masih di room
  io.to(code).emit('room:playerLeft', {
    playerName: leavingPlayer.name,
    players:    room.players,
    newHost,
  });
}

// ── Cleanup rooms lama (setiap 30 menit) ─────────────────────
setInterval(() => {
  const now     = Date.now();
  const maxAge  = 3 * 60 * 60 * 1000; // 3 jam
  let deleted   = 0;
  for (const [code, room] of rooms) {
    if (now - room.createdAt > maxAge) {
      rooms.delete(code);
      deleted++;
    }
  }
  if (deleted > 0) console.log(`[CLEANUP] Deleted ${deleted} stale rooms`);
}, 30 * 60 * 1000);

// ── Start Server ──────────────────────────────────────────────
const PORT = process.env.PORT || 3001;
server.listen(PORT, () => {
  console.log(`
╔═══════════════════════════════════════╗
║   SpinDecide Realtime Server          ║
║   Running on port ${PORT}               ║
║   http://localhost:${PORT}              ║
╚═══════════════════════════════════════╝
  `);
});
