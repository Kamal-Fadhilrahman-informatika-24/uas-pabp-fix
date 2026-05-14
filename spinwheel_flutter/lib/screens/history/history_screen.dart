// ============================================================
// screens/history/history_screen.dart
// Selaras dengan history.html + history.js di web project
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/spin_provider.dart';
import '../../models/spin_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'all'; // all | today | week
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpinProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<SpinModel> _applyFilter(List<SpinModel> data) {
    final now = DateTime.now();
    List<SpinModel> filtered = data;

    // Filter tanggal
    if (_filter == 'today') {
      filtered = filtered.where((s) {
        return s.createdAt.year == now.year &&
            s.createdAt.month == now.month &&
            s.createdAt.day == now.day;
      }).toList();
    } else if (_filter == 'week') {
      final weekAgo = now.subtract(const Duration(days: 7));
      filtered = filtered.where((s) => s.createdAt.isAfter(weekAgo)).toList();
    }

    // Search
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      filtered = filtered.where((s) =>
          s.result.toLowerCase().contains(q) ||
          s.options.any((o) => o.toLowerCase().contains(q))).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<SpinProvider>(
      builder: (context, prov, _) {
        final filtered = _applyFilter(prov.history);

        return Scaffold(
          appBar: AppBar(
            title: const Text('📋 Riwayat Spin'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: prov.loadHistory,
                tooltip: 'Refresh',
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Statistik ─────────────────────────────────────
              _StatsBar(prov: prov),

              // ── Search bar ────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari hasil atau pilihan...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),

              // ── Filter pills ──────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _FilterPill(
                        label: 'Semua',
                        value: 'all',
                        current: _filter,
                        onTap: (v) => setState(() => _filter = v)),
                    const SizedBox(width: 8),
                    _FilterPill(
                        label: 'Hari Ini',
                        value: 'today',
                        current: _filter,
                        onTap: (v) => setState(() => _filter = v)),
                    const SizedBox(width: 8),
                    _FilterPill(
                        label: '7 Hari',
                        value: 'week',
                        current: _filter,
                        onTap: (v) => setState(() => _filter = v)),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Jumlah hasil
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} riwayat',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Daftar history ────────────────────────────────
              Expanded(
                child: prov.isLoadingHistory
                    ? const Center(child: CircularProgressIndicator())
                    : prov.historyError != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.error_outline,
                                    size: 48, color: Colors.red),
                                const SizedBox(height: 12),
                                Text('Gagal memuat: ${prov.historyError}'),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: prov.loadHistory,
                                  child: const Text('Coba Lagi'),
                                ),
                              ],
                            ),
                          )
                        : filtered.isEmpty
                            ? _EmptyHistory(search: _search)
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 20),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) =>
                                    _HistoryCard(spin: filtered[i], index: i),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Stats bar ─────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final SpinProvider prov;
  const _StatsBar({required this.prov});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _Stat(label: 'Total Spin', value: '${prov.totalSpins}',
              icon: '🎯'),
          _Divider(),
          _Stat(
              label: 'Paling Sering',
              value: prov.mostFrequentResult,
              icon: '🏆'),
          _Divider(),
          _Stat(
              label: 'Rata-rata Opsi',
              value: prov.avgOptions.toStringAsFixed(1),
              icon: '📊'),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 40, width: 1, color: Colors.grey.withOpacity(0.2),
        margin: const EdgeInsets.symmetric(horizontal: 12));
  }
}

class _Stat extends StatelessWidget {
  final String label, value, icon;
  const _Stat({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
        ],
      ),
    );
  }
}

// ── History card ──────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final SpinModel spin;
  final int index;
  const _HistoryCard({required this.spin, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat('d MMMM yyyy', 'id_ID');
    final tf = DateFormat('HH:mm');

    final previewOpts = spin.options.take(4).join(', ') +
        (spin.options.length > 4 ? ' +${spin.options.length - 4} lagi' : '');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🏆 ${spin.result}',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: cs.primary),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        df.format(spin.createdAt),
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withOpacity(0.5)),
                      ),
                      Text(
                        tf.format(spin.createdAt),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withOpacity(0.7)),
                      ),
                    ],
                  ),
                  // ── TAMBAHAN: tombol delete ──────────────────
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: cs.onSurface.withOpacity(0.35),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Pilihan (${spin.options.length}): $previewOpts',
                style: TextStyle(
                    fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Lihat Detail →',
                  style: TextStyle(fontSize: 12, color: cs.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialog konfirmasi delete ──────────────────────────────────
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat?'),
        content: Text('Hasil "${spin.result}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await context.read<SpinProvider>().deleteHistory(spin.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal hapus: $e'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('🏆 Hasil: ${spin.result}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              DateFormat('d MMMM yyyy, HH:mm', 'id_ID').format(spin.createdAt),
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5)),
            ),
            const SizedBox(height: 16),
            const Text('Semua Pilihan:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: spin.options.map((opt) {
                final isWinner = opt == spin.result;
                return Chip(
                  label: Text(opt),
                  backgroundColor: isWinner
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      : null,
                  side: isWinner
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.primary)
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyHistory extends StatelessWidget {
  final String search;
  const _EmptyHistory({required this.search});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text(
              search.isNotEmpty
                  ? 'Tidak ada hasil untuk "$search"'
                  : 'Belum ada riwayat.\nMulai spin dulu!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter pill ───────────────────────────────────────────────
class _FilterPill extends StatelessWidget {
  final String label, value, current;
  final void Function(String) onTap;
  const _FilterPill(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active ? cs.primary : Colors.grey.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : cs.onSurface.withOpacity(0.7),
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
