// ============================================================
// screens/truth_or_dare/truth_or_dare_screen.dart
// Spin berhenti → pilih Truth atau Dare dulu → baru muncul soal
// ============================================================

import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/spin_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/audio_service.dart';

class TruthOrDareScreen extends StatefulWidget {
  const TruthOrDareScreen({super.key});

  @override
  State<TruthOrDareScreen> createState() => _TruthOrDareScreenState();
}

class _TruthOrDareScreenState extends State<TruthOrDareScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _spinAngle = 0.0;
  double _lastCtrlValue = 0.0;
  double _totalRotation = 0.0;
  bool _isSpinning = false;
  String? _currentQuestion;
  bool _isCurrentTruth = true;

  final List<String> _players = [];
  final _playerCtrl = TextEditingController();
  int? _currentPlayer;

  // ── Mute ────────────────────────────────────────────────────
  bool _soundEnabled = true;
  List<String>? _lastPlayers;

  // ── Riwayat ─────────────────────────────────────────────────
  final List<_HistoryEntry> _history = [];

  static const _truthQuestions = [
    'Apa hal paling memalukan yang pernah kamu lakukan?',
    'Siapa yang kamu suka di grup ini?',
    'Apa kebohongan terbesar yang pernah kamu ucapkan?',
    'Kapan terakhir kali kamu nangis dan kenapa?',
    'Apa hal yang paling kamu takutin?',
    'Siapa orang yang paling kamu rindukan?',
    'Apa rahasia yang belum pernah kamu ceritain ke siapapun?',
    'Apa hal yang paling kamu sesali dalam hidup?',
    'Kamu pernah ghosting seseorang? Kenapa?',
    'Apa mimpi yang paling aneh yang pernah kamu alami?',
  ];

  static const _dareActions = [
    'Lakukan 20 push-up sekarang!',
    'Nyanyikan lagu favorit kamu dengan suara keras selama 30 detik!',
    'Kirimin pesan "I miss you" ke kontak pertama di HP kamu!',
    'Lakukan joget TikTok selama 1 menit!',
    'Foto selfie aneh dan jadikan foto profil selama 1 jam!',
    'Telepon seseorang dan bilang kamu suka dia!',
    'Minum 1 gelas air dalam 10 detik!',
    'Lakukan impression orang lain di grup ini!',
    'Ceritakan lelucon terburuk yang kamu tau!',
    'Biarkan orang lain posting status apapun dari HP kamu!',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );
    _ctrl.addListener(() {
      if (!mounted) return;
      final delta = _ctrl.value - _lastCtrlValue;
      _lastCtrlValue = _ctrl.value;
      setState(() => _spinAngle += delta * _totalRotation);
    });
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _onSpinDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _playerCtrl.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning) return;
    if (_players.length < 2) {
      _showSnack('Tambahkan minimal 2 pemain!');
      return;
    }
    if (_soundEnabled) AudioService().playSpin();
    final rng = math.Random();
    // Reset sudut ke 0 agar setiap spin benar-benar random dari awal
    _spinAngle = 0.0;
    _lastCtrlValue = 0.0;
    _totalRotation = math.pi * 2 * (5 + rng.nextDouble() * 5);
    _ctrl.duration = Duration(
        milliseconds: (4000 + rng.nextDouble() * 1000).toInt());
    _ctrl.reset();
    setState(() {
      _isSpinning = true;
      _currentQuestion = null;
      _currentPlayer = null;
      _lastPlayers = [..._players]; // simpan snapshot untuk tombol Repres
    });
    _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  // ── Spin selesai → tampilkan dialog pilih Truth/Dare dulu ──
  void _onSpinDone() {
    if (_players.isEmpty) return;
    final arc = math.pi * 2 / _players.length;
    final normalized =
        ((_spinAngle % (math.pi * 2)) + math.pi * 2) % (math.pi * 2);
    final pointerAngle = (math.pi * 2 - normalized) % (math.pi * 2);
    final playerIndex = (pointerAngle / arc).floor() % _players.length;

    HapticFeedback.heavyImpact();
    if (_soundEnabled) AudioService().playWin();
    setState(() {
      _isSpinning = false;
      _currentPlayer = playerIndex;
      _currentQuestion = null;
    });

    // Tampilkan dialog pilihan Truth atau Dare
    _showChoiceDialog(_players[playerIndex], playerIndex);
  }

  // ── Riwayat helpers ────────────────────────────────────────
  void _addHistory(String result, {String? subtitle}) {
    setState(() {
      _history.insert(
        0,
        _HistoryEntry(
          result: result,
          subtitle: subtitle,
          time: DateTime.now(),
        ),
      );
      if (_history.length > 50) _history.removeLast();
    });
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _HistorySheet(history: _history, label: '🤔 Truth or Dare'),
    );
  }

  // ── Dialog 1: Pilih Truth atau Dare ───────────────────────
  void _showChoiceDialog(String player, int playerIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎯', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(
                player,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih tantanganmu!',
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Tombol TRUTH
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQuestionDialog(player, true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4D96FF), Color(0xFF0066CC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4D96FF).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Column(
                          children: [
                            Text('🫣', style: TextStyle(fontSize: 28)),
                            SizedBox(height: 6),
                            Text(
                              'TRUTH',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Tombol DARE
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showQuestionDialog(player, false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFCC0000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: const Column(
                          children: [
                            Text('😈', style: TextStyle(fontSize: 28)),
                            SizedBox(height: 6),
                            Text(
                              'DARE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog 2: Roda spin soal Truth / Dare ─────────────────
  void _showQuestionDialog(String player, bool isTruth) {
    setState(() => _isCurrentTruth = isTruth);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _QuestionWheelDialog(
        player: player,
        isTruth: isTruth,
        questions: isTruth ? _truthQuestions : _dareActions,
        soundEnabled: _soundEnabled,
        onSpinAgain: () {
          Navigator.pop(ctx);
          _startSpin();
        },
        onClose: () => Navigator.pop(ctx),
        onQuestionSelected: (question) {
          _addHistory(
            player,
            subtitle: '${isTruth ? "Truth" : "Dare"}: $question',
          );
          // Simpan ke riwayat global (HistoryScreen)
          final prov = context.read<SpinProvider>();
          prov.options
            ..clear()
            ..addAll(_players);
          final idx = _players.indexOf(player);
          if (idx >= 0) prov.onSpinComplete(idx);
        },
      ),
    );
  }

  void _addPlayer() {
    final name = _playerCtrl.text.trim();
    if (name.isEmpty) return;
    if (_players.contains(name)) {
      _showSnack('Nama sudah ada!');
      return;
    }
    if (_players.length >= 10) {
      _showSnack('Maksimal 10 pemain!');
      return;
    }
    setState(() => _players.add(name));
    _playerCtrl.clear();
    HapticFeedback.lightImpact();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }

  static const _playerColors = [
    Color(0xFF4D96FF), Color(0xFFFF6B6B), Color(0xFF51CF66),
    Color(0xFFFFD43B), Color(0xFFCC5DE8), Color(0xFFFF922B),
    Color(0xFF20C997), Color(0xFFE64980), Color(0xFF74C0FC), Color(0xFFA9E34B),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤔 Truth or Dare'),
        actions: [
          if (_players.length >= 2)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'Acak urutan pemain',
              onPressed: _isSpinning
                  ? null
                  : () {
                      setState(() => _players.shuffle(math.Random()));
                      HapticFeedback.lightImpact();
                      _showSnack('Urutan pemain diacak!');
                    },
            ),
          if (_lastPlayers != null)
            IconButton(
              icon: const Icon(Icons.replay),
              tooltip: 'Ulangi spin terakhir',
              onPressed: _isSpinning
                  ? null
                  : () {
                      setState(() {
                        _players.clear();
                        _players.addAll(_lastPlayers!);
                        _currentPlayer = null;
                        _currentQuestion = null;
                      });
                      _showSnack('Daftar pemain spin terakhir dimuat!');
                    },
            ),
          IconButton(
            icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
            tooltip: _soundEnabled ? 'Matikan suara' : 'Hidupkan suara',
            onPressed: () => setState(() {
              _soundEnabled = !_soundEnabled;
              AudioService().soundEnabled = _soundEnabled;
            }),
          ),
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Riwayat spin',
              onPressed: _showHistorySheet,
            ),
        ],
      ),
      body: Column(
        children: [
          // Roda spin pemain
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: CustomPaint(
                            painter: _TodWheelPainter(
                              players: _players,
                              angle: _spinAngle,
                              highlightIndex: _currentPlayer,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: SizedBox(
                            width: 30,
                            height: 22,
                            child: CustomPaint(
                              painter: _PointerPainter(),
                            ),
                          ),
                        ),
                        if (_players.isEmpty)
                          const Text(
                            'Tambahkan pemain\ndi bawah',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.grey, fontSize: 14),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _startSpin,
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: _isSpinning
                            ? null
                            : const LinearGradient(colors: [
                                Color(0xFF4D96FF),
                                Color(0xFFFF6B6B),
                              ]),
                        color: _isSpinning ? Colors.grey : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          _isSpinning ? '🌀 Berputar...' : '🎲 SPIN!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Panel pemain
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _playerCtrl,
                          decoration: InputDecoration(
                            hintText: 'Nama pemain...',
                            prefixIcon: const Icon(Icons.person_add_outlined,
                                size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          onSubmitted: (_) => _addPlayer(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _addPlayer,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                          child: const Icon(Icons.add, size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: _players.isEmpty
                      ? const Center(
                          child: Text('Belum ada pemain',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 13)),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          itemCount: _players.length,
                          itemBuilder: (_, i) {
                            final color =
                                _playerColors[i % _playerColors.length];
                            final isActive = i == _currentPlayer;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(isActive ? 0.2 : 0.07),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: color.withOpacity(
                                        isActive ? 0.6 : 0.2)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: color,
                                    child: Text(
                                      _players[i][0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_players[i],
                                        style: TextStyle(
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 13,
                                        )),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _players.removeAt(i)),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wheel Painter untuk ToD ───────────────────────────────────
class _TodWheelPainter extends CustomPainter {
  final List<String> players;
  final double angle;
  final int? highlightIndex;

  static const _colors = [
    Color(0xFF4D96FF), Color(0xFFFF6B6B), Color(0xFF51CF66),
    Color(0xFFFFD43B), Color(0xFFCC5DE8), Color(0xFFFF922B),
    Color(0xFF20C997), Color(0xFFE64980), Color(0xFF74C0FC), Color(0xFFA9E34B),
  ];

  const _TodWheelPainter(
      {required this.players, required this.angle, this.highlightIndex});

  @override
  void paint(Canvas canvas, Size size) {
    if (players.isEmpty) {
      final paint = Paint()
        ..color = Colors.grey.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(size.center(Offset.zero), size.width / 2, paint);
      return;
    }
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final arc = math.pi * 2 / players.length;

    for (int i = 0; i < players.length; i++) {
      final startAngle = angle + arc * i;
      final color = _colors[i % _colors.length];
      final isHighlight = i == highlightIndex;

      final paint = Paint()
        ..color = isHighlight ? color : color.withOpacity(0.85)
        ..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, arc, true, paint);

      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, arc, true, borderPaint);

      final textAngle = startAngle + arc / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * math.cos(textAngle);
      final textY = center.dy + textRadius * math.sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + math.pi / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: players[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight:
                isHighlight ? FontWeight.w800 : FontWeight.w600,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: radius * 0.7);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Center circle
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, centerPaint);
    final centerBorder = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, 18, centerBorder);
  }

  @override
  bool shouldRepaint(_TodWheelPainter old) =>
      old.angle != angle || old.highlightIndex != highlightIndex;
}

// ── Dialog Roda Soal (Truth / Dare) ──────────────────────────
class _QuestionWheelDialog extends StatefulWidget {
  final String player;
  final bool isTruth;
  final List<String> questions;
  final VoidCallback onSpinAgain;
  final VoidCallback onClose;
  final bool soundEnabled;
  final void Function(String question)? onQuestionSelected;

  const _QuestionWheelDialog({
    required this.player,
    required this.isTruth,
    required this.questions,
    required this.onSpinAgain,
    required this.onClose,
    required this.soundEnabled,
    this.onQuestionSelected,
  });

  @override
  State<_QuestionWheelDialog> createState() => _QuestionWheelDialogState();
}

class _QuestionWheelDialogState extends State<_QuestionWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _angle = 0.0;
  double _lastVal = 0.0;
  double _totalRot = 0.0;
  bool _spinning = false;
  int? _resultIndex;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addListener(() {
      if (!mounted) return;
      final delta = _ctrl.value - _lastVal;
      _lastVal = _ctrl.value;
      setState(() => _angle += delta * _totalRot);
    });
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _onDone();
    });
    // Auto-spin saat dialog terbuka
    WidgetsBinding.instance.addPostFrameCallback((_) => _spin());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _spin() {
    if (_spinning) return;
    if (widget.soundEnabled) AudioService().playSpin();
    final rng = math.Random();
    _angle = 0.0;
    _lastVal = 0.0;
    _resultIndex = null;
    _totalRot = math.pi * 2 * (5 + rng.nextDouble() * 5);
    _ctrl.duration =
        Duration(milliseconds: (3500 + rng.nextDouble() * 1000).toInt());
    _ctrl.reset();
    setState(() => _spinning = true);
    _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _onDone() {
    final count = widget.questions.length;
    final arc = math.pi * 2 / count;
    final normalized = ((_angle % (math.pi * 2)) + math.pi * 2) % (math.pi * 2);
    final pointerAngle = (math.pi * 2 - normalized) % (math.pi * 2);
    final idx = (pointerAngle / arc).floor() % count;
    HapticFeedback.heavyImpact();
    if (widget.soundEnabled) AudioService().playWin();
    setState(() {
      _spinning = false;
      _resultIndex = idx;
    });
    // Catat riwayat soal yang terpilih
    widget.onQuestionSelected?.call(widget.questions[idx]);
  }

  @override
  Widget build(BuildContext context) {
    final isTruth = widget.isTruth;
    final color1 = isTruth ? const Color(0xFF4D96FF) : const Color(0xFFFF6B6B);
    final color2 = isTruth ? const Color(0xFF0066CC) : const Color(0xFFCC0000);
    final resultQuestion =
        _resultIndex != null ? widget.questions[_resultIndex!] : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(isTruth ? '🤔' : '😈',
                style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 4),
            Text(
              widget.player,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: color1.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isTruth ? 'TRUTH' : 'DARE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: color1,
                  fontSize: 12,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Roda soal + pointer
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: _QuestionWheelPainter(
                        questions: widget.questions,
                        angle: _angle,
                        highlightIndex: _resultIndex,
                        baseColor: color1,
                      ),
                    ),
                  ),
                  // Pointer atas
                  Positioned(
                    right: 0,
                    child: SizedBox(
                      width: 30,
                      height: 22,
                      child: CustomPaint(
                          painter: _PointerPainter()) ,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Hasil soal
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: resultQuestion != null
                  ? Container(
                      key: ValueKey(resultQuestion),
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color1, color2],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        resultQuestion,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Container(
                      key: const ValueKey('spinning'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        '🌀 Memutar...',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Tombol
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onClose,
                    child: const Text('Tutup'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _spinning ? null : widget.onSpinAgain,
                    child: const Text('Spin Pemain'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Painter roda soal ─────────────────────────────────────────
class _QuestionWheelPainter extends CustomPainter {
  final List<String> questions;
  final double angle;
  final int? highlightIndex;
  final Color baseColor;

  const _QuestionWheelPainter({
    required this.questions,
    required this.angle,
    required this.baseColor,
    this.highlightIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final count = questions.length;
    final arc = math.pi * 2 / count;

    // Warna segmen bergantian terang/gelap dari baseColor
    final colors = List.generate(count, (i) {
      final t = i / count;
      return Color.lerp(baseColor, baseColor.withOpacity(0.45), t)!;
    });

    for (int i = 0; i < count; i++) {
      final startAngle = angle + arc * i;
      final isHighlight = i == highlightIndex;

      final paint = Paint()
        ..color = isHighlight
            ? Colors.white.withOpacity(0.95)
            : colors[i % colors.length]
        ..style = PaintingStyle.fill;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          arc,
          true,
          paint);

      final borderPaint = Paint()
        ..color = Colors.white.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          arc,
          true,
          borderPaint);

      // Label nomor soal di segmen (teks penuh terlalu panjang untuk roda kecil)
      final textAngle = startAngle + arc / 2;
      final textRadius = radius * 0.62;
      final tx = center.dx + textRadius * math.cos(textAngle);
      final ty = center.dy + textRadius * math.sin(textAngle);

      canvas.save();
      canvas.translate(tx, ty);
      canvas.rotate(textAngle + math.pi / 2);

      final label = 'S${i + 1}'; // S1, S2, ... singkatan Soal
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: isHighlight ? baseColor : Colors.white,
            fontSize: 11,
            fontWeight:
                isHighlight ? FontWeight.w900 : FontWeight.w700,
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Center circle
    canvas.drawCircle(
        center,
        16,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        center,
        16,
        Paint()
          ..color = Colors.grey.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_QuestionWheelPainter old) =>
      old.angle != angle || old.highlightIndex != highlightIndex;
}

// ── Pointer atas (segitiga ke bawah) ─────────────────────────
class _TopPointerPainter extends CustomPainter {
  final Color color;
  const _TopPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TopPointerPainter old) => old.color != color;
}


// ── Pointer kanan (segitiga ke kiri) ─────────────────────────
class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter _) => false;
}

// ── Model Riwayat ─────────────────────────────────────────────
class _HistoryEntry {
  final String result;
  final String? subtitle;
  final DateTime time;
  _HistoryEntry({required this.result, this.subtitle, required this.time});
}

// ── Bottom Sheet Riwayat ──────────────────────────────────────
class _HistorySheet extends StatelessWidget {
  final List<_HistoryEntry> history;
  final String label;
  const _HistorySheet({required this.history, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              Text('Riwayat $label',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${history.length} entri',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.45))),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: history.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = history[i];
                final hh = e.time.hour.toString().padLeft(2, '0');
                final mm = e.time.minute.toString().padLeft(2, '0');
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: CircleAvatar(
                    radius: 18,
                    backgroundColor: cs.primary.withOpacity(0.12),
                    child: Text('${i + 1}',
                        style: TextStyle(fontSize: 12, color: cs.primary,
                            fontWeight: FontWeight.w700)),
                  ),
                  title: Text(e.result,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: e.subtitle != null
                      ? Text(e.subtitle!,
                          style: TextStyle(fontSize: 12,
                              color: cs.onSurface.withOpacity(0.55)),
                          maxLines: 2, overflow: TextOverflow.ellipsis)
                      : null,
                  trailing: Text('$hh:$mm',
                      style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}