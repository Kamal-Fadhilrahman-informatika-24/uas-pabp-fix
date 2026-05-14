-- ============================================================
-- SUPABASE_RLS_FIX.sql
-- Jalankan ini di Supabase Dashboard → SQL Editor
-- untuk mengaktifkan DELETE permission pada tabel 'spins'
-- ============================================================

-- ── LANGKAH 1: Pastikan RLS aktif pada tabel spins ───────────
ALTER TABLE spins ENABLE ROW LEVEL SECURITY;

-- ── LANGKAH 2: Cek policy yang sudah ada ─────────────────────
-- (Jalankan ini dulu untuk lihat kondisi saat ini)
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'spins';

-- ── LANGKAH 3: Tambah policy DELETE (jika belum ada) ─────────
-- Policy ini memastikan user hanya bisa DELETE data miliknya sendiri
CREATE POLICY "Users can delete own spins"
  ON spins
  FOR DELETE
  USING (auth.uid() = user_id);

-- ── LANGKAH 4: Pastikan policy SELECT dan INSERT juga ada ─────
-- (Agar history tetap bisa dibaca dan disimpan)

-- Policy SELECT: user hanya bisa lihat data sendiri
CREATE POLICY "Users can view own spins"
  ON spins
  FOR SELECT
  USING (auth.uid() = user_id);

-- Policy INSERT: user hanya bisa insert data sendiri
CREATE POLICY "Users can insert own spins"
  ON spins
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ── CATATAN ───────────────────────────────────────────────────
-- Jika policy sudah ada dan muncul error "policy already exists",
-- hapus dulu dengan perintah di bawah, lalu buat ulang:
--
-- DROP POLICY IF EXISTS "Users can delete own spins" ON spins;
-- DROP POLICY IF EXISTS "Users can view own spins" ON spins;
-- DROP POLICY IF EXISTS "Users can insert own spins" ON spins;
--
-- Atau gunakan perintah CREATE OR REPLACE (Postgres 15+):
-- (Supabase saat ini masih Postgres 14/15, cek versi dulu)
-- ============================================================
