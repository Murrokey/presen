import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/student_screen.dart';
import 'screens/teacher_screen.dart';
import 'services/nearby_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();

  final supabaseService = SupabaseService();
  await supabaseService.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: supabaseService),
        ChangeNotifierProvider(create: (_) => NearbyService()),
      ],
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
        '/home': (context) => const StudentScreen(),
      },
      //   '/home': (context) {
      //   //   final isTeacher = supabaseService.currentUser?.role == 'teacher';
      //   //   return isTeacher ? const TeacherScreen() : const StudentScreen();
      //   // },
      //   // '/student': (context) => const StudentScreen(),
      //   // '/teacher': (context) => const TeacherScreen(),
      // },
    );
  }
}
