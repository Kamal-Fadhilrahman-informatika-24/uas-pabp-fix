// ============================================================
// screens/settings/settings_screen.dart
// Dark mode toggle, sound, favorit, logout
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/spin_provider.dart';
import '../../services/supabase_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemeProvider>();
    final spinProv = context.watch<SpinProvider>();
    final supa = SupabaseService();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info user ────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: cs.primary.withOpacity(0.2),
                    child: Text(
                      supa.userName.isNotEmpty
                          ? supa.userName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: cs.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supa.userName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        Text(
                          supa.currentUser?.email ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.5)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Tampilan ─────────────────────────────────────────
          const _SectionHeader('Tampilan'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Dark Mode'),
                  subtitle: Text(
                      themeProv.isDark ? 'Tema gelap aktif' : 'Tema terang aktif'),
                  secondary: Icon(
                      themeProv.isDark ? Icons.dark_mode : Icons.light_mode),
                  value: themeProv.isDark,
                  onChanged: (_) => themeProv.toggle(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Audio ─────────────────────────────────────────────
          const _SectionHeader('Audio'),
          Card(
            child: SwitchListTile(
              title: const Text('Sound Effect'),
              subtitle: const Text('Suara saat spin dan hasil keluar'),
              secondary: Icon(
                  spinProv.soundEnabled ? Icons.volume_up : Icons.volume_off),
              value: spinProv.soundEnabled,
              onChanged: (_) => spinProv.toggleSound(),
            ),
          ),
          const SizedBox(height: 12),

          // ── Favorit ───────────────────────────────────────────
          const _SectionHeader('Favorit Opsi'),
          Card(
            child: spinProv.favorites.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.favorite_border),
                    title: Text('Belum ada favorit'),
                    subtitle: Text(
                        'Tap ikon ❤️ di spin screen untuk menyimpan opsi favorit'),
                  )
                : Column(
                    children: spinProv.favorites.map((fav) {
                      return ListTile(
                        leading: const Icon(Icons.favorite,
                            color: Colors.pinkAccent, size: 20),
                        title: Text(fav),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 20),
                          onPressed: () => spinProv.toggleFavorite(fav),
                          tooltip: 'Hapus dari favorit',
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),

          // ── Statistik ─────────────────────────────────────────
          const _SectionHeader('Statistik Kamu'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow('🎯 Total Spin', '${spinProv.totalSpins}x'),
                  const Divider(height: 20),
                  _StatRow(
                      '🏆 Hasil Paling Sering', spinProv.mostFrequentResult),
                  const Divider(height: 20),
                  _StatRow('📊 Rata-rata Opsi per Spin',
                      spinProv.avgOptions.toStringAsFixed(1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Tentang ───────────────────────────────────────────
          const _SectionHeader('Tentang'),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('SpinWheel App'),
                  subtitle: Text('Versi 1.0.0'),
                ),
                ListTile(
                  leading: Icon(Icons.code),
                  title: Text('Tech Stack'),
                  subtitle: Text('Flutter + Supabase'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Logout ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Keluar',
                  style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(0, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Keluar?'),
                    content:
                        const Text('Kamu akan keluar dari akun ini.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Batal')),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await SupabaseService().logout();
                  // AuthState listener di main.dart akan redirect ke login
                }
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label, value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7)))),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}
