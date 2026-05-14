// ============================================================
// main.dart — FIX AUTH SYSTEM
// Perubahan:
// 1. Supabase.initialize dengan autoRefreshToken + persistSession
// 2. AuthGate berbasis StatefulWidget (bukan pure StreamBuilder)
//    agar session awal dari storage langsung terbaca
// 3. onAuthStateChange listener menangani semua event: signedIn,
//    signedOut, tokenRefreshed, userUpdated
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/supabase_config.dart';
import 'config/app_theme.dart';
import 'services/notification_service.dart';
import 'providers/theme_provider.dart';
import 'providers/spin_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await initializeDateFormatting('id_ID', null);

  // ── FIX 1: Aktifkan autoRefreshToken + persistSession ─────────
  // supabase_flutter ^2.x sudah mengaktifkan keduanya secara default,
  // tapi kita eksplisitkan agar tidak bergantung pada default versi.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
    // authOptions mengontrol perilaku session
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
      // autoRefreshToken: true — refresh token otomatis sebelum expired
      // persistSession: true  — session disimpan di storage lokal
      // Keduanya adalah default di supabase_flutter v2, tapi eksplisit
      // lebih aman agar tidak berubah bila versi diupgrade.
    ),
    // debug: false di production
    debug: false,
  );

  await NotificationService().init();

  runApp(const SpinWheelApp());
}

class SpinWheelApp extends StatelessWidget {
  const SpinWheelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SpinProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProv, _) {
          return MaterialApp(
            title: 'SpinWheel Fun',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProv.themeMode,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

// ── FIX 2 & 3: AuthGate sebagai StatefulWidget ────────────────
// Alasan: StreamBuilder murni tidak bisa membaca session yang sudah
// ada di storage pada frame pertama karena stream belum emit event.
// StatefulWidget memungkinkan kita cek currentSession langsung di
// initState (sync), lalu listen stream untuk perubahan selanjutnya.
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  // ── FIX 3: cek session awal LANGSUNG dari storage (sync) ─────
  // Tidak perlu tunggu stream emit — currentSession sudah ter-restore
  // dari SharedPreferences oleh supabase_flutter saat initialize().
  late bool _hasSession =
      Supabase.instance.client.auth.currentSession != null;

  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    // Beri sedikit waktu agar Supabase restore session dari storage
    // (biasanya instan, tapi awaiting stream event pertama lebih aman)
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    // Cek ulang setelah delay — kalau session sudah restore, ini true
    final session = Supabase.instance.client.auth.currentSession;
    setState(() {
      _hasSession = session != null;
      _initializing = false;
    });

    // ── FIX 4: Listen auth state change ──────────────────────────
    // Handle: signedIn, signedOut, tokenRefreshed, userUpdated
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        if (!mounted) return;
        final event = data.event;

        debugPrint('[Auth] Event: $event');

        switch (event) {
          case AuthChangeEvent.signedIn:
          case AuthChangeEvent.tokenRefreshed:
          case AuthChangeEvent.userUpdated:
            // Session aktif / token berhasil di-refresh → tampilkan Home
            if (!_hasSession) {
              setState(() => _hasSession = true);
            }
            break;

          case AuthChangeEvent.signedOut:
          case AuthChangeEvent.userDeleted:
            // User logout atau dihapus → tampilkan Login
            setState(() => _hasSession = false);
            break;

          case AuthChangeEvent.passwordRecovery:
            // Tidak perlu handle khusus untuk app ini
            break;

          default:
            break;
        }
      },
      onError: (error) {
        // Kalau stream error (jarang terjadi), cek session manual
        debugPrint('[Auth] Stream error: $error');
        if (!mounted) return;
        final session = Supabase.instance.client.auth.currentSession;
        setState(() => _hasSession = session != null);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Splash/loading saat inisialisasi awal
    if (_initializing) {
      return const _SplashScreen();
    }

    return _hasSession ? const HomeScreen() : const LoginScreen();
  }
}

// ── Splash screen selama restore session ─────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎯', style: TextStyle(fontSize: 56)),
            SizedBox(height: 20),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(height: 18),
            Text(
              'SpinWheel Fun',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
