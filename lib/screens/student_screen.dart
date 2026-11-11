import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/subject.dart';
import '../services/nearby_service.dart';
import '../services/supabase_service.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen> {
  List<Subject> _mySubjects = [];
  bool _isLoadingSubjects = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentData();
    });
  }

  Future<void> _loadStudentData() async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    setState(() => _isLoadingSubjects = true);

    await supabaseService.fetchCatalogData();

    if (mounted) {
      final user = supabaseService.currentUser;
      final courseName = user?.enrolledCourseName ?? '';

      if (supabaseService.careers.isEmpty) {
        setState(() {
          _mySubjects = [];
          _isLoadingSubjects = false;
        });
        return;
      }

      final matchedCareer = supabaseService.careers.firstWhere(
        (c) => courseName.contains(c.name),
        orElse: () => supabaseService.careers.first,
      );

      int studentYearLevel = 1;
      final yearMatch = RegExp(r'(\d+)').firstMatch(courseName);
      if (yearMatch != null) {
        studentYearLevel = int.tryParse(yearMatch.group(1)!) ?? 1;
      }

      _mySubjects = supabaseService.subjects
          .where(
            (s) =>
                s.careerId == matchedCareer.id &&
                s.yearLevel == studentYearLevel,
          )
          .toList();

      setState(() => _isLoadingSubjects = false);
    }
  }

  void _onStartAttendance() {
    final nearbyService = Provider.of<NearbyService>(context, listen: false);
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final user = supabaseService.currentUser;

    if (user != null) {
      nearbyService.startAdvertising(
        user.fullName,
        user.enrolledCourseName ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearbyService = Provider.of<NearbyService>(context);
    final supabaseService = Provider.of<SupabaseService>(context);
    final user = supabaseService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopBar(user, supabaseService),
              const SizedBox(height: 20),
              Expanded(
                child: nearbyService.attendanceConfirmed
                    ? _buildConfirmedState(nearbyService)
                    : nearbyService.isAdvertising
                    ? _buildSearchingState(nearbyService)
                    : _buildDefaultState(user, nearbyService),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(user, SupabaseService supabaseService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¡Hola, ${user?.firstName ?? 'Alumno'}!',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                user?.enrolledCourseName?.split(' ').take(3).join(' ') ??
                    'Sin curso',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF6C63FF),
                ),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white70),
          tooltip: 'Cerrar sesión',
          onPressed: () async {
            await supabaseService.logoutUser();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          },
        ),
      ],
    );
  }

  Widget _buildDefaultState(user, NearbyService nearbyService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mis Materias',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingSubjects
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
                )
              : _mySubjects.isEmpty
              ? Center(
                  child: Text(
                    'No hay materias registradas para tu curso.',
                    style: GoogleFonts.inter(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _mySubjects.length,
                  itemBuilder: (context, index) {
                    final subject = _mySubjects[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/student-history',
                          arguments: subject,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6C63FF)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: Color(0xFF6C63FF),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${subject.weeklyHours} horas semanales',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: Colors.white54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white30,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _onStartAttendance,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sensors_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Dar Asistencia',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingState(NearbyService nearbyService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
            border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: const SizedBox(
            height: 70,
            width: 70,
            child: CircularProgressIndicator(
              color: Color(0xFF6C63FF),
              strokeWidth: 4,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Esperando al profesor...',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Mantén tu celular cerca del aula para registrar la asistencia.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 15, color: Colors.white60),
        ),
        const SizedBox(height: 48),
        OutlinedButton(
          onPressed: () => nearbyService.stopAdvertising(),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Cancelar',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmedState(NearbyService nearbyService) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.greenAccent.withValues(alpha: 0.15),
            border: Border.all(color: Colors.greenAccent, width: 2),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 80,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          '¡Asistencia Confirmada!',
          style: GoogleFonts.outfit(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'El profesor registró tu presente en:',
          style: GoogleFonts.inter(fontSize: 15, color: Colors.white70),
        ),
        const SizedBox(height: 6),
        Text(
          nearbyService.confirmedClassName.isNotEmpty
              ? nearbyService.confirmedClassName
              : 'Clase registrada',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => nearbyService.stopAdvertising(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Text(
            'Entendido',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
