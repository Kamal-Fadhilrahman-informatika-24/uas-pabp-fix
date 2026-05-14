// ============================================================
// screens/home_screen.dart
// Dashboard utama + bottom nav History & Settings
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/spin_provider.dart';
import '../services/supabase_service.dart';
import 'spin/spin_screen.dart';
import 'truth_or_dare/truth_or_dare_screen.dart';
import 'spin_bareng/spin_bareng_screen.dart';
import 'bubble_spin/bubble_spin_screen.dart';
import 'history/history_screen.dart';
import 'settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpinProvider>().loadHistory();
    });
  }

  void _navigate(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _DashboardView(onNavigate: _navigate),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Setelan',
          ),
        ],
      ),
    );
  }
}

// ── Dashboard View ───────────────────────────────────────────
class _DashboardView extends StatelessWidget {
  final void Function(Widget) onNavigate;
  const _DashboardView({required this.onNavigate});

  static const _features = [
    _FeatureItem(
      icon: '🎯',
      title: 'Spin Normal',
      subtitle: 'Putar roda dengan pilihan bebas',
      gradient: [Color(0xFF4D96FF), Color(0xFF6B5CE7)],
      screen: SpinScreen(),
    ),
    _FeatureItem(
      icon: '🤔',
      title: 'Truth or Dare',
      subtitle: 'Spin pemain dan dapatkan tantangan',
      gradient: [Color(0xFFFF6B6B), Color(0xFFCC0044)],
      screen: TruthOrDareScreen(),
    ),
    _FeatureItem(
      icon: '👥',
      title: 'Spin Bareng',
      subtitle: 'Buat room & spin bareng teman realtime',
      gradient: [Color(0xFF51CF66), Color(0xFF20C997)],
      screen: SpinBarengScreen(),
    ),
    _FeatureItem(
      icon: '🫧',
      title: 'Bubble Spin',
      subtitle: 'Pembagian tugas otomatis secara acak',
      gradient: [Color(0xFFFFD43B), Color(0xFFFF922B)],
      screen: BubbleSpinScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService().userName;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4D96FF), Color(0xFF6B5CE7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.25),
                        child: Text(
                          user.isNotEmpty
                              ? user[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Halo,',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          Text(
                            user,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '🎰 SpinWheel',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih fitur yang ingin kamu gunakan',
                    style:
                        TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Stats row
          SliverToBoxAdapter(
            child: Consumer<SpinProvider>(
              builder: (_, prov, __) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Row(
                  children: [
                    _StatCard(
                      label: 'Total Spin',
                      value: '${prov.totalSpins}',
                      icon: Icons.casino,
                      color: const Color(0xFF4D96FF),
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: 'Paling Sering',
                      value: prov.mostFrequentResult,
                      icon: Icons.emoji_events,
                      color: const Color(0xFFFFD43B),
                    ),
                    const SizedBox(width: 10),
                    _StatCard(
                      label: 'Rata Opsi',
                      value: prov.avgOptions.toStringAsFixed(1),
                      icon: Icons.format_list_numbered,
                      color: const Color(0xFF51CF66),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'Pilih Fitur',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),

          // Feature grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final f = _features[i];
                  return _FeatureCard(
                    item: f,
                    onTap: () => onNavigate(f.screen),
                  );
                },
                childCount: _features.length,
              ),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.88,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature Card ─────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  final VoidCallback onTap;
  const _FeatureCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: item.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: item.gradient[0].withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.icon,
                  style: const TextStyle(fontSize: 36)),
              const Spacer(),
              Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Buka',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward,
                        color: Colors.white, size: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Widget screen;
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.screen,
  });
}

// ── Stat Card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}
