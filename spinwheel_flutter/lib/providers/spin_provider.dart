// ============================================================
// providers/spin_provider.dart
// State management spin: options, animasi, history, favorit
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/spin_model.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';

class SpinProvider extends ChangeNotifier {
  final _supa = SupabaseService();
  final _notif = NotificationService();
  final _audio = AudioService();

  // ── Daftar opsi ──────────────────────────────────────────────
  List<String> options = [];
  static const int maxOptions = 12;

  // ── State spin ───────────────────────────────────────────────
  bool isSpinning = false;
  double currentAngle = 0.0;
  String? lastResult;
  int? winnerIndex;

  // ── History ──────────────────────────────────────────────────
  List<SpinModel> history = [];
  bool isLoadingHistory = false;
  String? historyError;

  // ── Favorit opsi ─────────────────────────────────────────────
  Set<String> favorites = {};

  // ── Sound toggle ─────────────────────────────────────────────
  bool get soundEnabled => _audio.soundEnabled;
  void toggleSound() {
    _audio.soundEnabled = !_audio.soundEnabled;
    notifyListeners();
    _savePrefs();
  }

  SpinProvider() {
    _loadPrefs();
  }

  // ── Tambah opsi ──────────────────────────────────────────────
  bool addOption(String text) {
    text = text.trim();
    if (text.isEmpty) return false;
    if (options.length >= maxOptions) return false;
    if (options.contains(text)) return false;
    options.add(text);
    notifyListeners();
    return true;
  }

  // ── Hapus opsi ───────────────────────────────────────────────
  void removeOption(int index) {
    if (index >= 0 && index < options.length) {
      options.removeAt(index);
      notifyListeners();
    }
  }

  // ── Shuffle (acak) urutan opsi ───────────────────────────────
  void shuffleOptions() {
    options.shuffle();
    notifyListeners();
  }

  // ── Toggle favorit ───────────────────────────────────────────
  void toggleFavorite(String option) {
    if (favorites.contains(option)) {
      favorites.remove(option);
    } else {
      favorites.add(option);
    }
    notifyListeners();
    _savePrefs();
  }

  bool isFavorite(String option) => favorites.contains(option);

  // ── Load favorit ke opsi ─────────────────────────────────────
  void loadFavoritesToOptions() {
    for (final f in favorites) {
      if (!options.contains(f) && options.length < maxOptions) {
        options.add(f);
      }
    }
    notifyListeners();
  }

  // ── Repeat spin terakhir ─────────────────────────────────────
  void repeatLastSpin() {
    if (history.isEmpty) return;
    final last = history.first;
    options = List<String>.from(last.options);
    notifyListeners();
  }

  // ── Reset options ────────────────────────────────────────────
  void clearOptions() {
    options.clear();
    winnerIndex = null;
    notifyListeners();
  }

  // ── SPIN (dipanggil dari WheelPainter via animasi) ───────────
  // CATATAN: playSpin() TIDAK dipanggil di sini.
  // Dipanggil langsung dari UI (spin_screen.dart) agar
  // browser/Flutter web mengizinkan audio (user gesture policy).
  Future<void> spin(TickerProvider vsync) async {
    if (isSpinning || options.length < 2) return;

    isSpinning = true;
    winnerIndex = null;
    lastResult = null;
    notifyListeners();

    // Animasi ditangani di SpinScreen via AnimationController
    // Provider hanya menyimpan state; lihat spin_screen.dart
  }

  // ── Dipanggil setelah animasi selesai ────────────────────────
  Future<void> onSpinComplete(int winner) async {
    winnerIndex = winner;
    lastResult = options[winner];
    isSpinning = false;
    notifyListeners();

    await _audio.playWin();

    // Simpan ke Supabase
    try {
      await _supa.saveSpin(
        options: List<String>.from(options),
        result: lastResult!,
      );
    } catch (e) {
      debugPrint('Gagal simpan spin: $e');
    }

    // Notifikasi lokal
    await _notif.showSpinResult(lastResult!);

    // Refresh history
    loadHistory();
  }

  // ── Load history dari Supabase ───────────────────────────────
  Future<void> loadHistory() async {
    isLoadingHistory = true;
    historyError = null;
    notifyListeners();

    try {
      history = await _supa.getHistory();
    } catch (e) {
      historyError = e.toString();
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  // ── Hapus satu item history (by id) ──────────────────────────
  Future<void> deleteHistory(String id) async {
    await _supa.deleteSpin(id);
    history.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  // ── Statistik sederhana ──────────────────────────────────────
  int get totalSpins => history.length;

  String get mostFrequentResult {
    if (history.isEmpty) return '-';
    final freq = <String, int>{};
    for (final s in history) {
      freq[s.result] = (freq[s.result] ?? 0) + 1;
    }
    return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double get avgOptions {
    if (history.isEmpty) return 0;
    return history.map((s) => s.options.length).reduce((a, b) => a + b) /
        history.length;
  }

  // ── Persist favorit & sound pref ─────────────────────────────
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final favList = prefs.getStringList('favorites') ?? [];
    favorites = Set<String>.from(favList);
    _audio.soundEnabled = prefs.getBool('sound_enabled') ?? true;
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', favorites.toList());
    await prefs.setBool('sound_enabled', _audio.soundEnabled);
  }
}
