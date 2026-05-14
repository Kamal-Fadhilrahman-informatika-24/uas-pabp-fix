// ============================================================
// services/supabase_service.dart
// Semua operasi Supabase: Auth + Database (tabel "spins")
// Logic selaras dengan auth.js dan history.js di web project
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/spin_model.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get _client => Supabase.instance.client;

  // ── Cek session aktif ─────────────────────────────────────────
  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentSession != null;

  // ── Stream untuk perubahan auth state ────────────────────────
  Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  // ── REGISTER ─────────────────────────────────────────────────
  Future<AuthResponse> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name}, // simpan nama di metadata — sama seperti web
    );
  }

  // ── LOGIN ─────────────────────────────────────────────────────
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── LOGOUT ───────────────────────────────────────────────────
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  // ── Simpan hasil spin ke tabel "spins" ────────────────────────
  // Struktur sama dengan saveSpinResult() di spin.js
  Future<void> saveSpin({
    required List<String> options,
    required String result,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Belum login');

    await _client.from(SupabaseConfig.spinsTable).insert({
      'user_id': user.id,
      'options': options,
      'result': result,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ── Ambil riwayat spin user (urut terbaru) ────────────────────
  // Selaras dengan loadHistory() di history.js
  Future<List<SpinModel>> getHistory({int limit = 100}) async {
    final user = currentUser;
    if (user == null) return [];

    final response = await _client
        .from(SupabaseConfig.spinsTable)
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => SpinModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ── Hapus satu spin by id ─────────────────────────────────────
  Future<void> deleteSpin(String id) async {
    final user = currentUser;
    if (user == null) throw Exception('Belum login');

    await _client
        .from(SupabaseConfig.spinsTable)
        .delete()
        .eq('id', id)
        .eq('user_id', user.id); // pastikan hanya bisa hapus milik sendiri
  }

  // ── Nama user dari metadata ───────────────────────────────────
  String get userName {
    final meta = currentUser?.userMetadata;
    return meta?['name']?.toString() ?? currentUser?.email ?? 'User';
  }
}
