// ============================================================
// screens/spin/spin_screen.dart
// FIX: AnimationController + addListener agar roda benar-benar
//      berputar. Tambah shuffle, vibrate, UI polish.
// ============================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // HapticFeedback
import 'package:provider/provider.dart';
import '../../providers/spin_provider.dart';
import '../../widgets/wheel_painter.dart';
import '../../config/app_theme.dart';
import '../../services/audio_service.dart'; // FIX: audio dipanggil dari UI

class SpinScreen extends StatefulWidget {
  const SpinScreen({super.key});

  @override
  State<SpinScreen> createState() => _SpinScreenState();
}

class _SpinScreenState extends State<SpinScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;

  double _spinAngle = 0.0;
  double _lastCtrlValue = 0.0;
  double _totalRotation = 0.0;

  final _inputCtrl = TextEditingController();

  // Mode: false = Normal, true = Bobot
  bool _weightedMode = false;
  final _weightCtrl = TextEditingController(text: '1');

  // Map nama opsi -> bobot (untuk mode Bobot)
  final Map<String, int> _weights = {};

  bool _spinBtnPressed = false;
  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    // ── KRITIS: addListener memanggil setState tiap frame ────
    // Ini yang membuat roda berputar — tanpa ini CustomPainter
    // tidak tahu harus repaint karena tidak ada Listenable.
    _ctrl.addListener(() {
      if (!mounted) return;
      final delta = _ctrl.value - _lastCtrlValue;
      _lastCtrlValue = _ctrl.value;
      setState(() {
        _spinAngle += delta * _totalRotation;
      });
    });

    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onSpinDone();
      }
    });
  }

@override
void dispose() {
  _ctrl.dispose();
  _inputCtrl.dispose();
  _weightCtrl.dispose();
  super.dispose();

  }

  // ── Mulai spin ───────────────────────────────────────────────
  void _startSpin() {
    final prov = context.read<SpinProvider>();
    if (prov.isSpinning) return;
    if (prov.options.length < 2) {
      _showSnack('Tambahkan minimal 2 pilihan!');
      return;
    }

    if (prov.soundEnabled) {
      AudioService().playSpin();
    }

    // 5–10 putaran penuh
    _totalRotation =
        (math.pi * 2) * (5 + math.Random().nextDouble() * 5);
    _ctrl.duration = Duration(
        milliseconds: (4000 + math.Random().nextDouble() * 1000).toInt());

    _lastCtrlValue = 0.0;
    _ctrl.reset();

    prov.isSpinning = true;
    prov.winnerIndex = null;
    prov.notifyListeners();

    _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  // ── Pilih pemenang berdasarkan bobot ─────────────────────────
  int _pickWeightedWinner(List<String> options) {
    final totalWeight = options.fold<int>(
        0, (sum, opt) => sum + (_weights[opt] ?? 1));
    int rand = math.Random().nextInt(totalWeight);
    for (int i = 0; i < options.length; i++) {
      rand -= (_weights[options[i]] ?? 1);
      if (rand < 0) return i;
    }
    return options.length - 1;
  }

  // ── Selesai spin — hitung pemenang ───────────────────────────
  void _onSpinDone() {
    final prov = context.read<SpinProvider>();
    final options = prov.options;
    if (options.isEmpty) return;

    int winnerIndex;

    if (_weightedMode) {
      // Mode Bobot: pilih pemenang berdasarkan probabilitas bobot,
      // lalu animasikan roda berhenti di sektor pemenang tersebut.
      winnerIndex = _pickWeightedWinner(options);

      // Hitung sudut tengah sektor pemenang agar roda berhenti di sana
      final arc = (math.pi * 2) / options.length;
      final targetAngle = arc * winnerIndex + arc / 2;
      // Sesuaikan _spinAngle agar pointer menunjuk ke sektor pemenang
      final currentNorm =
          ((_spinAngle % (math.pi * 2)) + math.pi * 2) % (math.pi * 2);
      final diff = (targetAngle - ((math.pi * 2) - currentNorm) % (math.pi * 2) + math.pi * 2) % (math.pi * 2);
      setState(() {
        _spinAngle += diff;
      });
    } else {
      // Mode Normal: hitung dari posisi akhir roda
      final arc = (math.pi * 2) / options.length;
      final normalized =
          ((_spinAngle % (math.pi * 2)) + math.pi * 2) % (math.pi * 2);
      final pointerAngle = (math.pi * 2 - normalized) % (math.pi * 2);
      winnerIndex = (pointerAngle / arc).floor() % options.length;
    }

    HapticFeedback.heavyImpact();
    prov.onSpinComplete(winnerIndex);
    _showResultDialog(options[winnerIndex]);
  }

  // ── Dialog hasil ─────────────────────────────────────────────
  void _showResultDialog(String result) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bounce animation emoji
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1.0),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: const Text('🏆',
                    style: TextStyle(fontSize: 56)),
              ),
              const SizedBox(height: 8),
              const Text('Hasil Spin!',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              // Gradient result box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4D96FF), Color(0xFF6B5CE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4D96FF).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  result,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Spin Lagi'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startSpin();
                      },
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

  void _addOption() {
    final prov = context.read<SpinProvider>();
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) {
      _showSnack('Masukkan teks pilihan dulu!');
      return;
    }
    if (!prov.addOption(text)) {
      if (prov.options.length >= SpinProvider.maxOptions) {
        _showSnack('Maksimal ${SpinProvider.maxOptions} pilihan!');
      } else {
        _showSnack('Pilihan sudah ada!');
      }
      return;
    }
    // Simpan bobot jika mode Bobot aktif
    if (_weightedMode) {
      final w = int.tryParse(_weightCtrl.text.trim()) ?? 1;
      _weights[text] = w.clamp(1, 99);
    }
    _inputCtrl.clear();
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<SpinProvider>(
      builder: (context, prov, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('🎯 SpinWheel'),
            actions: [
              if (prov.options.length >= 2)
                IconButton(
                  icon: const Icon(Icons.shuffle),
                  tooltip: 'Acak urutan pilihan',
                  onPressed: prov.isSpinning
                      ? null
                      : () {
                          prov.shuffleOptions();
                          HapticFeedback.lightImpact();
                          _showSnack('Urutan diacak!');
                        },
                ),
              if (prov.history.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.replay),
                  tooltip: 'Ulangi spin terakhir',
                  onPressed: prov.isSpinning
                      ? null
                      : () {
                          prov.repeatLastSpin();
                          _showSnack('Opsi spin terakhir dimuat!');
                        },
                ),
              IconButton(
                icon: Icon(prov.soundEnabled
                    ? Icons.volume_up
                    : Icons.volume_off),
                onPressed: prov.toggleSound,
              ),
            ],
          ),
          body: Column(
            children: [
              // ── RODA SPIN ─────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Shadow roda
                            Positioned.fill(
                              child: Container(
                                margin: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          cs.primary.withOpacity(0.2),
                                      blurRadius: 32,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Roda — FIX: angle = _spinAngle di-update
                            // tiap frame via addListener + setState
                            AspectRatio(
                              aspectRatio: 1,
                              child: CustomPaint(
                                painter: WheelPainter(
                                  options: prov.options,
                                  angle: _spinAngle,
                                  highlightIndex: prov.winnerIndex,
                                ),
                              ),
                            ),
                            // Pointer kanan
                            Positioned(
                              right: 0,
                              child: SizedBox(
                                width: 30,
                                height: 22,
                                child: CustomPaint(
                                  painter: WheelPointerPainter(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Tombol SPIN dengan scale & gradient ───
                      GestureDetector(
                        onTapDown: (_) =>
                            setState(() => _spinBtnPressed = true),
                        onTapUp: (_) {
                          setState(() => _spinBtnPressed = false);
                          _startSpin();
                        },
                        onTapCancel: () =>
                            setState(() => _spinBtnPressed = false),
                        child: AnimatedScale(
                          scale: _spinBtnPressed ? 0.94 : 1.0,
                          duration: const Duration(milliseconds: 80),
                          child: Container(
                            width: double.infinity,
                            height: 54,
                            decoration: BoxDecoration(
                              gradient: prov.isSpinning
                                  ? null
                                  : const LinearGradient(
                                      colors: [
                                        Color(0xFF4D96FF),
                                        Color(0xFF6B5CE7),
                                      ],
                                    ),
                              color: prov.isSpinning
                                  ? Colors.grey.shade600
                                  : null,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: prov.isSpinning
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF4D96FF)
                                            .withOpacity(0.38),
                                        blurRadius: 14,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                            ),
                            child: Center(
                              child: Text(
                                prov.isSpinning
                                    ? '🌀  Berputar...'
                                    : '🎰  PUTAR!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── PANEL BAWAH ───────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(22)),
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
                    // Handle
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Mode toggle: Normal / Bobot
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: Row(
                        children: [
                          _ModeToggle(
                            value: _weightedMode,
                            onChanged: (v) => setState(() {
                              _weightedMode = v;
                              // Reset semua bobot ke 1 saat ganti mode
                              if (!v) _weights.clear();
                            }),
                          ),
                        ],
                      ),
                    ),

                    // Input
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputCtrl,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Ketik pilihan lalu Enter...',
                                prefixIcon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 20),
                                isDense: true,
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(11),
                                ),
                              ),
                              onSubmitted: (_) => _addOption(),
                            ),
                          ),
                          // Input bobot — hanya tampil saat mode Bobot
                          if (_weightedMode) ...[
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 62,
                              child: TextField(
                                controller: _weightCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: 'Bobot',
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _addOption,
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

                    // Toolbar: count + shuffle + favorit + hapus
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                      child: Row(
                        children: [
                          Text(
                            '${prov.options.length}/${SpinProvider.maxOptions} pilihan',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    cs.onSurface.withOpacity(0.45)),
                          ),
                          const Spacer(),
                          if (prov.options.length >= 2)
                            _ToolbarBtn(
                              icon: Icons.shuffle,
                              label: 'Acak',
                              onTap: prov.isSpinning
                                  ? null
                                  : prov.shuffleOptions,
                            ),
                          if (prov.favorites.isNotEmpty)
                            _ToolbarBtn(
                              icon: Icons.favorite,
                              label: 'Favorit',
                              color: Colors.pinkAccent,
                              onTap: prov.loadFavoritesToOptions,
                            ),
                          if (prov.options.isNotEmpty)
                            _ToolbarBtn(
                              icon: Icons.delete_outline,
                              label: 'Hapus',
                              color: cs.error,
                              onTap: prov.isSpinning
                                  ? null
                                  : prov.clearOptions,
                            ),
                        ],
                      ),
                    ),

                    // Daftar opsi
                    SizedBox(
                      height: 172,
                      child: prov.options.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🎯',
                                      style: TextStyle(
                                          fontSize: 28,
                                          color: cs.onSurface
                                              .withOpacity(0.2))),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Belum ada pilihan.\nTambahkan di atas!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: cs.onSurface
                                            .withOpacity(0.35)),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                  14, 2, 14, 14),
                              itemCount: prov.options.length,
                              itemBuilder: (_, i) {
                                final opt = prov.options[i];
                                final color = AppTheme.wheelColors[
                                    i % AppTheme.wheelColors.length];
                                final isWinner = i == prov.winnerIndex;
                                return AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 250),
                                  margin:
                                      const EdgeInsets.only(bottom: 5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isWinner
                                        ? color.withOpacity(0.18)
                                        : color.withOpacity(0.07),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color: color.withOpacity(
                                          isWinner ? 0.55 : 0.18),
                                      width: isWinner ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          opt,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isWinner
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      // Badge bobot
                                      if (_weightedMode)
                                        Container(
                                          margin: const EdgeInsets.only(right: 6),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.18),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                                color: color.withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            'x${_weights[opt] ?? 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: color,
                                            ),
                                          ),
                                        ),
                                      GestureDetector(
                                        onTap: () =>
                                            prov.toggleFavorite(opt),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(
                                            prov.isFavorite(opt)
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            size: 16,
                                            color: prov.isFavorite(opt)
                                                ? Colors.pinkAccent
                                                : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: prov.isSpinning
                                            ? null
                                            : () => prov.removeOption(i),
                                        child: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Icon(Icons.close,
                                              size: 16,
                                              color: Colors.grey
                                                  .withOpacity(0.7)),
                                        ),
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
      },
    );
  }
}

// ── Mode toggle: Normal / Bobot ──────────────────────────────
class _ModeToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ModeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: cs.surfaceVariant.withOpacity(0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Tab(
            label: '⚖️  Normal',
            active: !value,
            onTap: () => onChanged(false),
          ),
          _Tab(
            label: '🎲  Bobot',
            active: value,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? cs.onPrimary : cs.onSurface.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  const _ToolbarBtn(
      {required this.icon,
      required this.label,
      this.onTap,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ??
        Theme.of(context).colorScheme.onSurface.withOpacity(0.55);
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.3 : 1.0,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: c),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: c,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}