// ============================================================
// supabase.js - KONFIGURASI SUPABASE
// ============================================================
// LANGKAH: Ganti 2 baris di bawah dengan data dari:
//   Supabase Dashboard → Settings → API
// ============================================================

const SUPABASE_URL = 'https://thajggtojsvfohfadwfy.supabase.co';     // ← GANTI INI
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoYWpnZ3RvanN2Zm9oZmFkd2Z5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NzI1NTIsImV4cCI6MjA5MjE0ODU1Mn0.YNX84ZDEivQbkxYIzuB4ZbBTpaV9JhN1tqB4VkhLBDI';    // ← GANTI INI

// ============================================================
// Jangan ubah kode di bawah ini
// ============================================================

const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
