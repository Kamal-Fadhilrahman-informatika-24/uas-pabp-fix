// ============================================================
// services/audio_service.dart
// FIX: Turun ke audioplayers ^4.0.1 (kompatibel Dart 3.1)
// API v4 menggunakan setSource() + resume() atau play(source)
// ============================================================

import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  // v4.x: buat instance terpisah per suara
  final AudioPlayer _spinPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();

  bool soundEnabled = true;

  // ── Suara saat roda mulai berputar ───────────────────────────
  // audioplayers v4: AudioPlayer.play(Source) — sama seperti v6
  // bedanya: tidak ada setAudioContext, cukup try-catch kalau file tidak ada
  Future<void> playSpin() async {
    if (!soundEnabled) return;
    try {
      await _spinPlayer.stop();
      await _spinPlayer.play(AssetSource('sounds/spin.mp3'));
    } catch (_) {
      // File audio tidak ada — tidak crash, cukup skip
    }
  }

  // ── Suara saat hasil keluar ──────────────────────────────────
  Future<void> playWin() async {
    if (!soundEnabled) return;
    try {
      await _winPlayer.stop();
      await _winPlayer.play(AssetSource('sounds/win.mp3'));
    } catch (_) {}
  }

  Future<void> stopAll() async {
    await _spinPlayer.stop();
    await _winPlayer.stop();
  }

  void dispose() {
    _spinPlayer.dispose();
    _winPlayer.dispose();
  }
}
