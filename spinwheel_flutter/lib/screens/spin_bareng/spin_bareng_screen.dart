import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/spin_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/audio_service.dart';

class SpinBarengScreen extends StatefulWidget {
  const SpinBarengScreen({super.key});

  @override
  State<SpinBarengScreen> createState() => _SpinBarengScreenState();
}

class _SpinBarengScreenState extends State<SpinBarengScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;

  String? _roomCode;
  String? _myName;
  bool _isHost = false;
  bool _inRoom = false;
  List<Map<String, dynamic>> _roomMembers = [];
  List<String> _roomOptions = [];
  String? _roomResult;
  RealtimeChannel? _channel;

  late final AnimationController _ctrl;
  double _spinAngle = 0.0;
  double _lastCtrlValue = 0.0;
  double _totalRotation = 0.0;
  bool _isSpinning = false;

  final _nameCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _optionCtrl = TextEditingController();

  int _retryCount = 0;
  bool _soundEnabled = true;

  // ── Riwayat ─────────────────────────────────────────────────
  final List<_HistoryEntry> _history = [];

  // ─────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 4500));
    _ctrl.addListener(() {
      if (!mounted) return;
      final delta = _ctrl.value - _lastCtrlValue;
      _lastCtrlValue = _ctrl.value;
      setState(() => _spinAngle += delta * _totalRotation);
    });
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _onLocalSpinDone();
    });
  }

  @override
  void dispose() {
    _stopRetry();
    _channel?.unsubscribe();
    _ctrl.dispose();
    _nameCtrl.dispose();
    _roomCtrl.dispose();
    _optionCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Helper UI — didefinisikan di atas agar bisa dipanggil dari mana saja
  // ─────────────────────────────────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
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

  void _showResultDialog(String result) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              const Text('Hasil Spin Bareng!',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    Color(0xFF4D96FF),
                    Color(0xFF6B5CE7),
                  ]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  result,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Room logic
  // ─────────────────────────────────────────────────────────────

  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = math.Random();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  void _createRoom() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showSnack('Masukkan nama kamu dulu!');
      return;
    }
    final code = _generateCode();
    setState(() {
      _roomCode = code;
      _myName = name;
      _isHost = true;
      _roomMembers = [
        {'name': name, 'isHost': true}
      ];
      _roomOptions = [];
      _roomResult = null;
      _inRoom = true;
    });
    _subscribeRoom(code, name);
  }

  void _joinRoom() {
    final name = _nameCtrl.text.trim();
    final code = _roomCtrl.text.trim().toUpperCase();
    if (name.isEmpty || code.isEmpty) {
      _showSnack('Isi nama dan kode room!');
      return;
    }
    setState(() {
      _roomCode = code;
      _myName = name;
      _isHost = false;
      _roomMembers = [];
      _roomOptions = [];
      _inRoom = true;
    });
    _subscribeRoom(code, name);
  }

  void _subscribeRoom(String code, String name) {
    _channel = _client.channel('room:$code');

    _channel!.onBroadcast(
      event: 'member_join',
      callback: (payload) {
        final member = payload['member'] as Map<String, dynamic>?;
        if (member == null || !mounted) return;
        setState(() {
          if (!_roomMembers.any((m) => m['name'] == member['name'])) {
            _roomMembers.add(member);
          }
        });
        if (_isHost) _broadcastFullState();
      },
    );

    _channel!.onBroadcast(
      event: 'member_leave',
      callback: (payload) {
        final memberName = payload['name']?.toString();
        if (memberName == null || !mounted) return;
        setState(() =>
            _roomMembers.removeWhere((m) => m['name'] == memberName));
      },
    );

    _channel!.onBroadcast(
      event: 'full_state',
      callback: (payload) {
        if (!mounted) return;
        final members = payload['members'] as List?;
        final opts = payload['options'] as List?;
        setState(() {
          if (members != null) {
            _roomMembers = members
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          if (opts != null) {
            _roomOptions = opts.map((e) => e.toString()).toList();
          }
        });
        _stopRetry();
      },
    );

    _channel!.onBroadcast(
      event: 'options_update',
      callback: (payload) {
        final opts = payload['options'] as List?;
        if (opts == null || !mounted) return;
        setState(() =>
            _roomOptions = opts.map((e) => e.toString()).toList());
      },
    );

    _channel!.onBroadcast(
      event: 'request_state',
      callback: (payload) {
        if (_isHost && mounted) _broadcastFullState();
      },
    );

    _channel!.onBroadcast(
      event: 'spin_start',
      callback: (payload) {
        final rotation = (payload['rotation'] as num?)?.toDouble() ?? 0;
        final duration = (payload['duration'] as num?)?.toInt() ?? 4500;
        if (mounted) _doSpin(rotation, duration);
      },
    );

    _channel!.onBroadcast(
      event: 'spin_result',
      callback: (payload) {
        final result = payload['result']?.toString();
        if (result == null || !mounted) return;
        setState(() => _roomResult = result);
        _showResultDialog(result);
      },
    );

    _channel!.subscribe();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _channel!.sendBroadcastMessage(
        event: 'member_join',
        payload: {
          'member': {'name': name, 'isHost': _isHost}
        },
      );
      if (!_isHost) _startRetryRequestState();
    });
  }

  void _broadcastFullState() {
    _channel?.sendBroadcastMessage(
      event: 'full_state',
      payload: {
        'members': _roomMembers,
        'options': _roomOptions,
      },
    );
  }

  void _startRetryRequestState() {
    _retryCount = 0;
    _doRetry();
  }

  void _doRetry() {
    if (!mounted || _retryCount >= 6) return;
    if (_roomOptions.isNotEmpty) return;
    _retryCount++;
    _channel?.sendBroadcastMessage(
      event: 'request_state',
      payload: {'from': _myName},
    );
    Future.delayed(const Duration(milliseconds: 1500), _doRetry);
  }

  void _stopRetry() {
    _retryCount = 99;
  }

  void _addOption() {
    final opt = _optionCtrl.text.trim();
    if (opt.isEmpty) return;
    if (_roomOptions.contains(opt)) {
      _showSnack('Pilihan sudah ada!');
      return;
    }
    final newOpts = [..._roomOptions, opt];
    _optionCtrl.clear();
    setState(() => _roomOptions = newOpts);
    _channel!.sendBroadcastMessage(
      event: 'options_update',
      payload: {'options': newOpts},
    );
  }

  void _hostStartSpin() {
    if (_isSpinning) return;
    if (_roomOptions.length < 2) {
      _showSnack('Tambahkan minimal 2 pilihan!');
      return;
    }
    if (_soundEnabled) AudioService().playSpin();
    final rotation = math.pi * 2 * (5 + math.Random().nextDouble() * 5);
    final duration = (4000 + math.Random().nextDouble() * 1000).toInt();
    _channel!.sendBroadcastMessage(
      event: 'spin_start',
      payload: {'rotation': rotation, 'duration': duration},
    );
    _doSpin(rotation, duration);
  }

  void _shuffleOptions() {
    if (_isSpinning || _roomOptions.length < 2) return;
    final newOpts = List<String>.from(_roomOptions)..shuffle();
    setState(() => _roomOptions = newOpts);
    _channel!.sendBroadcastMessage(
      event: 'options_update',
      payload: {'options': newOpts},
    );
    HapticFeedback.lightImpact();
    _showSnack('Urutan diacak!');
  }

  void _resetOptions() {
    if (_isSpinning || _roomOptions.isEmpty) return;
    setState(() => _roomOptions = []);
    _channel!.sendBroadcastMessage(
      event: 'options_update',
      payload: {'options': <String>[]},
    );
    HapticFeedback.mediumImpact();
    _showSnack('Semua pilihan dihapus!');
  }

  void _doSpin(double rotation, int duration) {
    _totalRotation = rotation;
    _ctrl.duration = Duration(milliseconds: duration);
    _lastCtrlValue = 0.0;
    _ctrl.reset();
    setState(() {
      _isSpinning = true;
      _roomResult = null;
    });
    _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _onLocalSpinDone() {
    if (_roomOptions.isEmpty) return;
    final arc = math.pi * 2 / _roomOptions.length;
    final normalized =
        ((_spinAngle % (math.pi * 2)) + math.pi * 2) % (math.pi * 2);
    final pointerAngle = (math.pi * 2 - normalized) % (math.pi * 2);
    final winnerIdx = (pointerAngle / arc).floor() % _roomOptions.length;
    final result = _roomOptions[winnerIdx];

    HapticFeedback.heavyImpact();
    if (_soundEnabled) AudioService().playWin();
    setState(() {
      _isSpinning = false;
      _roomResult = result;
      _history.insert(0, _HistoryEntry(
        result: result,
        subtitle: 'Room: ${_roomCode ?? '-'} · Spin oleh ${_isHost ? "Host" : _myName ?? "-"}',
        time: DateTime.now(),
      ));
      if (_history.length > 50) _history.removeLast();
    });

    // Simpan ke riwayat global (HistoryScreen)
    if (mounted) {
      final prov = context.read<SpinProvider>();
      prov.options
        ..clear()
        ..addAll(_roomOptions);
      prov.onSpinComplete(winnerIdx);
    }

    if (_isHost) {
      _channel!.sendBroadcastMessage(
        event: 'spin_result',
        payload: {'result': result},
      );
    }
    _showResultDialog(result);
  }

  void _leaveRoom() {
    _stopRetry();
    _channel?.sendBroadcastMessage(
      event: 'member_leave',
      payload: {'name': _myName},
    );
    _channel?.unsubscribe();
    setState(() {
      _inRoom = false;
      _roomCode = null;
      _myName = null;
      _isHost = false;
      _roomMembers = [];
      _roomOptions = [];
      _roomResult = null;
      _channel = null;
      _retryCount = 0;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  static const _wheelColors = [
    Color(0xFF4D96FF), Color(0xFFFF6B6B), Color(0xFF51CF66),
    Color(0xFFFFD43B), Color(0xFFCC5DE8), Color(0xFFFF922B),
    Color(0xFF20C997), Color(0xFFE64980),
  ];

  @override
  Widget build(BuildContext context) {
    if (!_inRoom) return _buildLobby();
    return _buildRoom();
  }

  Widget _buildLobby() {
    return Scaffold(
      appBar: AppBar(title: const Text('👥 Spin Bareng')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nama kamu',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'Masukkan nama...',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            // Buat room
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF4D96FF),
                  Color(0xFF6B5CE7),
                ]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('🏠 Buat Room Baru',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Kamu jadi host, bagikan kode ke teman',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _createRoom,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF4D96FF),
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Buat Room',
                        style:
                            TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Gabung room
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Colors.grey.withOpacity(0.3), width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('🔗 Gabung Room',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text('Masukkan kode dari teman kamu',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _roomCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Kode Room (6 karakter)',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _joinRoom,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Gabung',
                        style:
                            TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoom() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('👥 Spin Bareng',
                style: TextStyle(fontSize: 16)),
            Row(
              children: [
                Text('Kode: $_roomCode',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.white70)),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: _roomCode!));
                    _showSnack('Kode disalin!');
                  },
                  child: const Icon(Icons.copy,
                      size: 14, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_isHost && _roomOptions.length >= 2)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'Acak urutan pilihan',
              onPressed: _isSpinning ? null : _shuffleOptions,
            ),
          if (_isHost && _roomOptions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus semua pilihan',
              onPressed: _isSpinning ? null : _resetOptions,
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
              onPressed: () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => _HistorySheet(history: _history, label: '👥 Spin Bareng'),
              ),
            ),
          TextButton(
            onPressed: _leaveRoom,
            child: const Text('Keluar',
                style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Member chips
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _roomMembers.length,
              itemBuilder: (_, i) {
                final m = _roomMembers[i];
                final isMe = m['name'] == _myName;
                return Container(
                  margin: const EdgeInsets.only(
                      right: 8, top: 6, bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  decoration: BoxDecoration(
                    color: isMe
                        ? cs.primary.withOpacity(0.15)
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: isMe
                        ? Border.all(
                            color: cs.primary.withOpacity(0.5))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (m['isHost'] == true)
                        const Text('👑 ',
                            style: TextStyle(fontSize: 11)),
                      Text(
                        m['name'].toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isMe
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Roda
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: CustomPaint(
                      painter: _RoomWheelPainter(
                        options: _roomOptions,
                        angle: _spinAngle,
                        colors: _wheelColors,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    child: SizedBox(
                      width: 30,
                      height: 22,
                      child: CustomPaint(
                          painter: _RoomPointerPainter()),
                    ),
                  ),
                  if (_roomOptions.isEmpty)
                    const Text(
                      'Host belum\nmenambahkan pilihan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                ],
              ),
            ),
          ),

          // Banner hasil
          if (_roomResult != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [
                  Color(0xFF4D96FF),
                  Color(0xFF6B5CE7),
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🏆 ',
                      style: TextStyle(fontSize: 18)),
                  Text(
                    _roomResult!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

          // Panel bawah
          Container(
            padding: const EdgeInsets.all(14),
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
                if (_isHost) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionCtrl,
                          decoration: InputDecoration(
                            hintText: 'Tambah pilihan...',
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                          onSubmitted: (_) => _addOption(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _addOption,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                          ),
                          child: const Icon(Icons.add,
                              size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                if (_roomOptions.isNotEmpty)
                  SizedBox(
                    height: 60,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _roomOptions.length,
                      itemBuilder: (_, i) {
                        final color = _wheelColors[
                            i % _wheelColors.length];
                        return Container(
                          margin: const EdgeInsets.only(
                              right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    color.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _roomOptions[i],
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: color),
                              ),
                              if (_isHost) ...[
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    final newOpts =
                                        List<String>.from(
                                            _roomOptions)
                                          ..removeAt(i);
                                    setState(() =>
                                        _roomOptions =
                                            newOpts);
                                    _channel!
                                        .sendBroadcastMessage(
                                      event:
                                          'options_update',
                                      payload: {
                                        'options': newOpts
                                      },
                                    );
                                  },
                                  child: Icon(Icons.close,
                                      size: 14,
                                      color: color),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
                if (_isHost)
                  GestureDetector(
                    onTap: _hostStartSpin,
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: _isSpinning
                            ? null
                            : const LinearGradient(colors: [
                                Color(0xFF4D96FF),
                                Color(0xFF6B5CE7),
                              ]),
                        color: _isSpinning
                            ? Colors.grey
                            : null,
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          _isSpinning
                              ? '🌀 Berputar...'
                              : '🎰 Mulai Spin!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _isSpinning
                            ? '🌀 Berputar...'
                            : '⏳ Menunggu host spin...',
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                      ),
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

// ─────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────

class _RoomWheelPainter extends CustomPainter {
  final List<String> options;
  final double angle;
  final List<Color> colors;

  const _RoomWheelPainter({
    required this.options,
    required this.angle,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (options.isEmpty) {
      canvas.drawCircle(
        size.center(Offset.zero),
        size.width / 2,
        Paint()..color = Colors.grey.withOpacity(0.15),
      );
      return;
    }
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final arc = math.pi * 2 / options.length;

    for (int i = 0; i < options.length; i++) {
      final startAngle = angle + arc * i;
      final color = colors[i % colors.length];

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, arc, true,
        Paint()..color = color.withOpacity(0.85),
      );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, arc, true,
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      final textAngle = startAngle + arc / 2;
      final tr = radius * 0.65;
      canvas.save();
      canvas.translate(
        center.dx + tr * math.cos(textAngle),
        center.dy + tr * math.sin(textAngle),
      );
      canvas.rotate(textAngle + math.pi / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: options[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: radius * 0.7);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(
      size.center(Offset.zero),
      16,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RoomWheelPainter old) => old.angle != angle;
}

class _RoomPointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
        path, Paint()..color = const Color(0xFFFF6B6B));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Model & Sheet Riwayat ────────────────────────────────────
class _HistoryEntry {
  final String result;
  final String? subtitle;
  final DateTime time;
  const _HistoryEntry({required this.result, this.subtitle, required this.time});
}

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