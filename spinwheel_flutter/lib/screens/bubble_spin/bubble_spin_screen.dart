import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../../providers/spin_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/audio_service.dart';

class BubbleSpinScreen extends StatefulWidget {
  const BubbleSpinScreen({super.key});

  @override
  State<BubbleSpinScreen> createState() => _BubbleSpinScreenState();
}

class _BubbleSpinScreenState extends State<BubbleSpinScreen>
    with TickerProviderStateMixin {
  // ── Tab ─────────────────────────────────────────────────────
  int _tab = 0; // 0=Setup, 1=Spin, 2=Hasil

  // ── Sound ────────────────────────────────────────────────────
  bool _soundEnabled = true;

  // ── Riwayat ─────────────────────────────────────────────────
  final List<_HistoryEntry> _history = [];

  // ── Data ────────────────────────────────────────────────────
  final List<String> _members = [];
  final List<String> _tasks = [];
  final _memberCtrl = TextEditingController();
  final _taskCtrl = TextEditingController();

  // Hasil akhir: member → tugas
  Map<String, String> _assignments = {};

  // ── Spin state ───────────────────────────────────────────────
  // Phase: 'member' = sedang spin anggota, 'task' = sedang spin tugas
  String _phase = 'member';

  List<String> _remainingMembers = []; // anggota yang belum dapat tugas
  List<String> _remainingTasks = [];   // tugas yang belum dipakai

  String? _selectedMember; // anggota yang baru saja keluar dari spin
  String? _selectedTask;   // tugas yang baru saja keluar dari spin

  late final AnimationController _spinCtrl;
  double _spinAngle = 0.0;
  double _lastCtrlValue = 0.0;
  double _totalRotation = 0.0;
  bool _isSpinning = false;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500));
    _spinCtrl.addListener(() {
      if (!mounted) return;
      final delta = _spinCtrl.value - _lastCtrlValue;
      _lastCtrlValue = _ctrl.value;
      setState(() => _spinAngle += delta * _totalRotation);
    });
    _spinCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) _onSpinDone();
    });
  }

  AnimationController get _ctrl => _spinCtrl;

  @override
  void dispose() {
    _spinCtrl.dispose();
    _memberCtrl.dispose();
    _taskCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Setup
  // ─────────────────────────────────────────────────────────────

  void _addMember() {
    final name = _memberCtrl.text.trim();
    if (name.isEmpty) return;
    if (_members.contains(name)) { _showSnack('Nama sudah ada!'); return; }
    if (_members.length >= 12) { _showSnack('Maksimal 12 anggota!'); return; }
    setState(() => _members.add(name));
    _memberCtrl.clear();
    HapticFeedback.lightImpact();
  }

  void _addTask() {
    final task = _taskCtrl.text.trim();
    if (task.isEmpty) return;
    if (_tasks.contains(task)) { _showSnack('Tugas sudah ada!'); return; }
    setState(() => _tasks.add(task));
    _taskCtrl.clear();
    HapticFeedback.lightImpact();
  }

  void _startSession() {
    if (_members.isEmpty) { _showSnack('Tambahkan anggota dulu!'); return; }
    if (_tasks.isEmpty) { _showSnack('Tambahkan tugas dulu!'); return; }
    setState(() {
      _assignments = {};
      _remainingMembers = [..._members]..shuffle(math.Random());
      _remainingTasks = [..._tasks]..shuffle(math.Random());
      _selectedMember = null;
      _selectedTask = null;
      _phase = 'member';
      _spinAngle = 0.0;
      _tab = 1;
    });
  }

  // ─────────────────────────────────────────────────────────────
  // Spin logic
  // ─────────────────────────────────────────────────────────────

  List<String> get _activeWheel =>
      _phase == 'member' ? _remainingMembers : _remainingTasks;

  void _doSpin() {
    if (_isSpinning || _activeWheel.isEmpty) return;
    if (_soundEnabled) AudioService().playSpin();
    _totalRotation = math.pi * 2 * (5 + math.Random().nextDouble() * 5);
    _ctrl.duration = Duration(
        milliseconds: (3000 + math.Random().nextDouble() * 1000).toInt());
    _lastCtrlValue = 0.0;
    _ctrl.reset();
    setState(() {
      _isSpinning = true;
      if (_phase == 'member') _selectedMember = null;
      else _selectedTask = null;
    });
    _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
  }

  void _onSpinDone() {
    final wheel = _activeWheel;
    if (wheel.isEmpty) return;

    final arc = math.pi * 2 / wheel.length;
    final normalized =
        ((_spinAngle % (math.pi * 2)) + math.pi * 2) % (math.pi * 2);
    final pointerAngle = (math.pi * 2 - normalized) % (math.pi * 2);
    final idx = (pointerAngle / arc).floor() % wheel.length;
    final picked = wheel[idx];

    HapticFeedback.heavyImpact();
    if (_soundEnabled) AudioService().playWin();

    setState(() {
      _isSpinning = false;
      if (_phase == 'member') {
        _selectedMember = picked;
      } else {
        _selectedTask = picked;
      }
    });
  }

  // Konfirmasi anggota → pindah ke phase spin tugas
  void _confirmMember() {
    if (_selectedMember == null) return;
    setState(() {
      _remainingMembers.remove(_selectedMember);
      _phase = 'task';
      _selectedTask = null;
      _spinAngle = 0.0;
    });
  }

  // Konfirmasi tugas → simpan assignment → cek apakah selesai
  void _confirmTask() {
    if (_selectedMember == null || _selectedTask == null) return;
    final member = _selectedMember!;
    final task = _selectedTask!;
    setState(() {
      _assignments[member] = task;
      _remainingTasks.remove(task);
      _selectedMember = null;
      _selectedTask = null;
      _phase = 'member';
      _spinAngle = 0.0;
      // Catat ke riwayat
      _history.insert(0, _HistoryEntry(
        result: member,
        subtitle: 'Tugas: $task',
        time: DateTime.now(),
      ));
      if (_history.length > 50) _history.removeLast();
    });

    // Simpan ke riwayat global (HistoryScreen)
    if (mounted) {
      final prov = context.read<SpinProvider>();
      final allNames = [..._members]; // semua anggota sebagai opsi roda
      prov.options
        ..clear()
        ..addAll(allNames);
      final winnerIdx = allNames.indexOf(member);
      if (winnerIdx >= 0) {
        prov.onSpinComplete(winnerIdx);
      }
    }

    // Selesai jika tidak ada anggota/tugas tersisa
    if (_remainingMembers.isEmpty || _remainingTasks.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _tab = 2);
      });
    }
  }

  void _spinAgain() {
    setState(() {
      if (_phase == 'member') {
        _selectedMember = null;
      } else {
        _selectedTask = null;
      }
      _spinAngle = 0.0;
    });
  }

  void _reset() {
    setState(() {
      _assignments = {};
      _remainingMembers = [];
      _remainingTasks = [];
      _selectedMember = null;
      _selectedTask = null;
      _phase = 'member';
      _spinAngle = 0.0;
      _isSpinning = false;
      _tab = 0;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ));
  }

  static const _colors = [
    Color(0xFF4D96FF), Color(0xFFFF6B6B), Color(0xFF51CF66),
    Color(0xFFFFD43B), Color(0xFFCC5DE8), Color(0xFFFF922B),
    Color(0xFF20C997), Color(0xFFE64980), Color(0xFF74C0FC),
    Color(0xFFA9E34B), Color(0xFFFF8787), Color(0xFF63E6BE),
  ];

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🫧 Bubble Spin'),
        actions: [
          if (_tab == 1 && _activeWheel.length >= 2)
            IconButton(
              icon: const Icon(Icons.shuffle),
              tooltip: 'Acak urutan',
              onPressed: _isSpinning
                  ? null
                  : () {
                      setState(() {
                        if (_phase == 'member') {
                          _remainingMembers.shuffle(math.Random());
                        } else {
                          _remainingTasks.shuffle(math.Random());
                        }
                      });
                      HapticFeedback.lightImpact();
                      _showSnack('Urutan diacak!');
                    },
            ),
          if (_tab == 1 && _assignments.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.replay),
              tooltip: 'Ulangi sesi spin',
              onPressed: _isSpinning
                  ? null
                  : () {
                      setState(() {
                        _assignments = {};
                        _remainingMembers = [..._members]
                          ..shuffle(math.Random());
                        _remainingTasks = [..._tasks]..shuffle(math.Random());
                        _selectedMember = null;
                        _selectedTask = null;
                        _phase = 'member';
                        _spinAngle = 0.0;
                      });
                      _showSnack('Sesi spin diulang!');
                    },
            ),
          if (_tab != 0)
            IconButton(
              icon: Icon(_soundEnabled ? Icons.volume_up : Icons.volume_off),
              tooltip: _soundEnabled ? 'Matikan suara' : 'Hidupkan suara',
              onPressed: () => setState(() {
                _soundEnabled = !_soundEnabled;
                AudioService().soundEnabled = _soundEnabled;
              }),
            ),
          if (_tab != 0 && _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Riwayat spin',
              onPressed: () => showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => _HistorySheet(history: _history, label: '🫧 Bubble Spin'),
              ),
            ),
          if (_tab != 0)
            TextButton(
              onPressed: _reset,
              child: const Text('Reset',
                  style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: [_buildSetup(), _buildSpin(), _buildResult()][_tab],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 0: Setup
  // ─────────────────────────────────────────────────────────────

  Widget _buildSetup() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Text('ℹ️', style: TextStyle(fontSize: 18)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Spin anggota dulu → dapat anggota → baru spin tugas untuk anggota tersebut.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Anggota
          _SectionHeader(
              icon: '👥', title: 'Anggota', count: _members.length),
          const SizedBox(height: 8),
          _InputRow(
              ctrl: _memberCtrl,
              hint: 'Nama anggota...',
              icon: Icons.person_add_outlined,
              onAdd: _addMember),
          const SizedBox(height: 8),
          if (_members.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _members.asMap().entries.map((e) {
                final color = _colors[e.key % _colors.length];
                return Chip(
                  label: Text(e.value,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: color.withOpacity(0.12),
                  side: BorderSide(color: color.withOpacity(0.4)),
                  deleteIcon: Icon(Icons.close, size: 14, color: color),
                  onDeleted: () =>
                      setState(() => _members.remove(e.value)),
                );
              }).toList(),
            ),
          const SizedBox(height: 20),

          // Tugas
          _SectionHeader(
              icon: '📋', title: 'Daftar Tugas', count: _tasks.length),
          const SizedBox(height: 8),
          _InputRow(
              ctrl: _taskCtrl,
              hint: 'Nama tugas...',
              icon: Icons.task_outlined,
              onAdd: _addTask),
          const SizedBox(height: 8),
          if (_tasks.isNotEmpty)
            Column(
              children: _tasks.asMap().entries.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Text('${e.key + 1}.',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(e.value,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500))),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _tasks.remove(e.value)),
                        child: const Icon(Icons.close,
                            size: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 28),

          // Tombol mulai
          GestureDetector(
            onTap: _startSession,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF51CF66), Color(0xFF20C997)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF51CF66).withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Center(
                child: Text('🎲 Mulai Spin!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: Spin
  // ─────────────────────────────────────────────────────────────

  Widget _buildSpin() {
    final isMemberPhase = _phase == 'member';
    final phaseColor = isMemberPhase
        ? const Color(0xFF4D96FF)
        : const Color(0xFFCC5DE8);
    final phaseLabel = isMemberPhase ? 'Spin Anggota' : 'Spin Tugas';
    final phaseIcon = isMemberPhase ? '👥' : '📋';
    final wheel = _activeWheel;
    final picked = isMemberPhase ? _selectedMember : _selectedTask;

    return Column(
      children: [
        // ── Header phase ────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: phaseColor.withOpacity(0.10),
            border: Border(
                bottom: BorderSide(color: phaseColor.withOpacity(0.2))),
          ),
          child: Row(
            children: [
              // Step 1
              _StepBadge(
                step: '1',
                label: 'Spin Anggota',
                isActive: isMemberPhase,
                isDone: !isMemberPhase || _selectedMember != null,
                activeColor: const Color(0xFF4D96FF),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_ios,
                    size: 12, color: Colors.grey.withOpacity(0.5)),
              ),
              // Step 2
              _StepBadge(
                step: '2',
                label: 'Spin Tugas',
                isActive: !isMemberPhase,
                isDone: false,
                activeColor: const Color(0xFFCC5DE8),
              ),
              const Spacer(),
              // Info sisa
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${_remainingMembers.length} anggota',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  Text('${_remainingTasks.length} tugas',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),

        // ── Banner anggota terpilih (saat phase tugas) ──────────
        if (!isMemberPhase && _selectedMember != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF4D96FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF4D96FF).withOpacity(0.4)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF4D96FF),
                  child: Text(
                    _selectedMember![0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Anggota terpilih:',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(_selectedMember!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Color(0xFF4D96FF))),
                  ],
                ),
                const Spacer(),
                const Text('🎯',
                    style: TextStyle(fontSize: 22)),
              ],
            ),
          ),

        // ── Roda ────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CustomPaint(
                    painter: _BubbleWheelPainter(
                      tasks: wheel.isEmpty ? ['Kosong'] : wheel,
                      angle: _spinAngle,
                      colors: isMemberPhase
                          ? _colors
                          : _colors.reversed.toList(),
                    ),
                  ),
                ),
                // Pointer kanan
                Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: CustomPaint(
                        size: const Size(36, 24),
                        painter: _RightPointerPainter(color: phaseColor),
                      ),
                    ),
                  ),
                ),
                // Label di tengah roda
                if (wheel.isEmpty)
                  const Text('✅',
                      style: TextStyle(fontSize: 40)),
              ],
            ),
          ),
        ),

        // ── Result banner ────────────────────────────────────────
        if (picked != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [phaseColor, phaseColor.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(phaseIcon,
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isMemberPhase
                            ? 'Anggota terpilih!'
                            : 'Tugas untuk ${_selectedMember ?? ""}:',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        picked,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // ── Panel tombol ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 10,
                  offset: const Offset(0, -2))
            ],
          ),
          child: Column(
            children: [
              if (_isSpinning)
                // Sedang berputar
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🌀 Berputar...',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                )
              else if (picked == null)
                // Belum spin
                _SpinButton(
                  label: '🎰 Spin $phaseLabel!',
                  color: phaseColor,
                  onTap: _doSpin,
                )
              else
                // Sudah dapat hasil → konfirmasi atau spin lagi
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _spinAgain,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Spin Lagi'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isMemberPhase
                            ? _confirmMember
                            : _confirmTask,
                        icon: Icon(
                            isMemberPhase
                                ? Icons.how_to_reg
                                : Icons.check_circle,
                            size: 16),
                        label: Text(
                          isMemberPhase
                              ? 'Pilih ${picked} → Spin Tugas'
                              : 'Konfirmasi Tugas',
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          backgroundColor: phaseColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),

              // Progress dots
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_members.length, (i) {
                  final name = i < _members.length ? _members[i] : '';
                  final isDone = _assignments.containsKey(name);
                  final color = _colors[i % _colors.length];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isDone ? 10 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: isDone
                          ? color
                          : color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),

              // Keterangan progress
              const SizedBox(height: 6),
              Text(
                '${_assignments.length} dari ${_members.length} anggota selesai',
                style: const TextStyle(
                    fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: Hasil
  // ─────────────────────────────────────────────────────────────

  Widget _buildResult() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF51CF66), Color(0xFF20C997)]),
          ),
          child: Column(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 4),
              const Text('Pembagian Tugas Selesai!',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text(
                '${_assignments.length} anggota · ${_tasks.length} tugas',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ..._assignments.entries.toList().asMap().entries.map((e) {
                final member = e.value.key;
                final task = e.value.value;
                final idx = _members.indexOf(member);
                final color =
                    idx >= 0 ? _colors[idx % _colors.length] : _colors[0];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: color,
                        child: Text(member[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: color)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.task_alt,
                                    size: 14,
                                    color: color.withOpacity(0.7)),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(task,
                                      style: const TextStyle(
                                          fontSize: 13)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.check_circle,
                          color: color.withOpacity(0.6), size: 22),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh),
                label: const Text('Mulai Ulang'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  final text = _assignments.entries
                      .map((e) => '${e.key} → ${e.value}')
                      .join('\n');
                  Clipboard.setData(ClipboardData(
                      text: '📋 Pembagian Tugas:\n$text'));
                  _showSnack('Disalin ke clipboard!');
                },
                icon: const Icon(Icons.copy),
                label: const Text('Salin Hasil'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widgets pembantu
// ─────────────────────────────────────────────────────────────

class _StepBadge extends StatelessWidget {
  final String step;
  final String label;
  final bool isActive;
  final bool isDone;
  final Color activeColor;

  const _StepBadge({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isDone,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor:
              isActive ? activeColor : Colors.grey.withOpacity(0.3),
          child: Text(step,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: color)),
      ],
    );
  }
}

class _SpinButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SpinButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient:
              LinearGradient(colors: [color, color.withOpacity(0.75)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;
  final int count;
  const _SectionHeader(
      {required this.icon, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(width: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primary
                .withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary)),
        ),
      ],
    );
  }
}

class _InputRow extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final VoidCallback onAdd;
  const _InputRow(
      {required this.ctrl,
      required this.hint,
      required this.icon,
      required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 11),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: (_) => onAdd(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 46,
          height: 46,
          child: ElevatedButton(
            onPressed: onAdd,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.add, size: 20),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────

class _BubbleWheelPainter extends CustomPainter {
  final List<String> tasks;
  final double angle;
  final List<Color> colors;

  const _BubbleWheelPainter(
      {required this.tasks, required this.angle, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    if (tasks.isEmpty) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final arc = math.pi * 2 / tasks.length;

    for (int i = 0; i < tasks.length; i++) {
      final startAngle = angle + arc * i;
      final color = colors[i % colors.length];
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle, arc, true,
          Paint()..color = color.withOpacity(0.88));
      canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle, arc, true,
          Paint()
            ..color = Colors.white.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);

      final textAngle = startAngle + arc / 2;
      final tr = radius * 0.62;
      canvas.save();
      canvas.translate(center.dx + tr * math.cos(textAngle),
          center.dy + tr * math.sin(textAngle));
      canvas.rotate(textAngle + math.pi / 2);
      final tp = TextPainter(
        text: TextSpan(
          text: tasks[i],
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Colors.black38, blurRadius: 3)]),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: radius * 0.65);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    canvas.drawCircle(center, 16, Paint()..color = Colors.white);
    canvas.drawCircle(
        center,
        16,
        Paint()
          ..color = Colors.grey.withOpacity(0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_BubbleWheelPainter old) =>
      old.angle != angle || old.tasks.length != tasks.length;
}

class _RightPointerPainter extends CustomPainter {
  final Color color;
  const _RightPointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPath = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
        shadowPath,
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));

    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_RightPointerPainter old) => old.color != color;
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