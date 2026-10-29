import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  final supabaseService = SupabaseService();
  await supabaseService.restoreSession();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: supabaseService)],
      child: const AttendanceApp(),
    ),
  );
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(context);

    return MaterialApp(
      title: 'Asistencia+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFF12121A),
      ),
      initialRoute: supabaseService.isAuthenticated ? '/home' : '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¡Adentro! Hola ${supabaseService.currentUser?.fullName}',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await supabaseService.logoutUser();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  child: const Text('Probar Cerrar Sesión'),
                ),
              ],
            ),
          ),
        ),
      },
    );
  }
}
