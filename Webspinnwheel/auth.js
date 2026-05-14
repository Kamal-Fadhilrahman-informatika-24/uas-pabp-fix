// ============================================================
// auth.js - LOGIN & REGISTER
// ============================================================

// ── Cek apakah user sudah login ──────────────────────────────
async function checkAuth() {
  const { data: { session } } = await supabaseClient.auth.getSession();
  return session;
}

// ── Redirect ke dashboard jika sudah login ───────────────────
async function requireGuest() {
  const session = await checkAuth();
  if (session) {
    window.location.href = 'dashboard.html';
  }
}

// ── Redirect ke login jika belum login ───────────────────────
async function requireAuth() {
  const session = await checkAuth();
  if (!session) {
    window.location.href = 'login.html';
  }
  return session;
}

// ── REGISTER ─────────────────────────────────────────────────
async function registerUser(name, email, password) {
  const { data, error } = await supabaseClient.auth.signUp({
    email,
    password,
    options: {
      data: { name } // simpan nama di metadata user
    }
  });

  if (error) throw error;
  return data;
}

// ── LOGIN ─────────────────────────────────────────────────────
async function loginUser(email, password) {
  const { data, error } = await supabaseClient.auth.signInWithPassword({
    email,
    password
  });

  if (error) throw error;
  return data;
}

// ── LOGOUT ───────────────────────────────────────────────────
async function logoutUser() {
  const { error } = await supabaseClient.auth.signOut();
  if (error) throw error;
  window.location.href = 'login.html';
}

// ── Ambil data user yang sedang login ────────────────────────
async function getCurrentUser() {
  const { data: { user } } = await supabaseClient.auth.getUser();
  return user;
}
