import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'services/supabase_service.dart';
import 'providers/app_providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const PosSerabiApp());
}

class PosSerabiApp extends StatelessWidget {
  const PosSerabiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => OutletProvider()),
      ],
      child: MaterialApp(
        title: 'POS Serabi Solo Kraton',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}

/// Menentukan halaman awal berdasarkan status login.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.profile == null) {
      return const LoginScreen();
    }
    return const DashboardShell();
  }
}
