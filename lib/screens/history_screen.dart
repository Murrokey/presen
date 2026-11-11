import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/course_class.dart';
import '../services/supabase_service.dart';

class HistoryScreen extends StatefulWidget {
  final CourseClass courseClass;

  const HistoryScreen({super.key, required this.courseClass});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _sessionHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClassHistory();
    });
  }

  Future<void> _loadClassHistory() async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final prefs = await SharedPreferences.getInstance();

    List<Map<String, dynamic>> loadedSessions = [];

    if (supabaseService.isCloudConfigured) {
      try {
        final enrolledData = await Supabase.instance.client
            .from('course_enrollments')
            .select('student_id, user_profiles!inner(first_name, last_name)')
            .eq('course_id', widget.courseClass.courseId);

        final List<Map<String, String>> allCourseStudents = [];
        for (var row in (enrolledData as List)) {
          final profile = row['user_profiles'];
          final fullName =
              '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                  .trim();
          allCourseStudents.add({
            'id': row['student_id'].toString(),
            'name': fullName,
          });
        }

        final sessionsData = await Supabase.instance.client
            .from('attendance_sessions')
            .select(
              'id, session_date, created_at, attendance_records(student_id, is_present, user_profiles(first_name, last_name))',
            )
            .eq('class_id', widget.courseClass.id)
            .order('created_at', ascending: false);

        for (var session in (sessionsData as List)) {
          final rawDate =
              (session['session_date'] ?? session['created_at'] ?? '')
                  .toString();
          final records = (session['attendance_records'] as List?) ?? [];

          final Set<String> presentIds = {};
          final List<String> presentNames = [];
          final List<String> absentNames = [];

          for (var rec in records) {
            final isPresent = rec['is_present'] ?? true;
            final sId = rec['student_id']?.toString() ?? '';
            final profile = rec['user_profiles'];
            final sName = profile != null
                ? '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                      .trim()
                : 'Alumno';

            if (isPresent) {
              presentIds.add(sId);
              if (!presentNames.contains(sName)) {
                presentNames.add(sName);
              }
            }
          }

          for (var student in allCourseStudents) {
            final sId = student['id']!;
            final sName = student['name']!;
            if (!presentIds.contains(sId) && !presentNames.contains(sName)) {
              absentNames.add(sName);
            }
          }

          presentNames.sort();
          absentNames.sort();

          loadedSessions.add({
            'date': _formatDate(rawDate),
            'presentes': presentNames,
            'ausentes': absentNames,
          });
        }

        await prefs.setString(
          'cached_history_${widget.courseClass.id}',
          jsonEncode(loadedSessions),
        );
      } catch (_) {}
    }

    if (loadedSessions.isEmpty) {
      final cached = prefs.getString('cached_history_${widget.courseClass.id}');
      if (cached != null && cached.isNotEmpty) {
        final decoded = jsonDecode(cached) as List;
        loadedSessions = decoded
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    if (loadedSessions.isEmpty) {
      final localHistory = prefs.getStringList('attendance_history') ?? [];
      for (var raw in localHistory) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          if (map['subject'] == widget.courseClass.subjectName &&
              map['course'] == widget.courseClass.courseName) {
            final presentList = List<String>.from(map['students'] ?? []);
            presentList.sort();
            loadedSessions.add({
              'date': _formatDate((map['date'] ?? '').toString()),
              'presentes': presentList,
              'ausentes': <String>[],
            });
          }
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _sessionHistory = loadedSessions;
        _isLoading = false;
      });
    }
  }

  String _formatDate(String rawDate) {
    final dt = DateTime.tryParse(rawDate);
    if (dt == null) return rawDate;
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} - $hour:$minute hs';
  }

  @override
  Widget build(BuildContext context) {
    final filteredSessions = _sessionHistory.where((session) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final dateStr = (session['date'] ?? '').toString().toLowerCase();
      final presentes = List<String>.from(session['presentes'] ?? []);
      final ausentes = List<String>.from(session['ausentes'] ?? []);

      final matchDate = dateStr.contains(q);
      final matchPresent = presentes.any((s) => s.toLowerCase().contains(q));
      final matchAbsent = ausentes.any((s) => s.toLowerCase().contains(q));

      return matchDate || matchPresent || matchAbsent;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Clases Fecha por Fecha',
              style: GoogleFonts.outfit(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.courseClass.subjectName} · ${widget.courseClass.courseName}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
              )
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      style: GoogleFonts.inter(color: Colors.white),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Buscar por fecha o alumno...',
                        hintStyle: GoogleFonts.inter(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF00B4D8),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredSessions.isEmpty
                          ? Center(
                              child: Text(
                                'No hay clases registradas para mostrar.',
                                style: GoogleFonts.inter(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredSessions.length,
                              itemBuilder: (context, index) {
                                final session = filteredSessions[index];
                                final date = session['date']?.toString() ?? '';
                                final presentes = List<String>.from(
                                  session['presentes'] ?? [],
                                );
                                final ausentes = List<String>.from(
                                  session['ausentes'] ?? [],
                                );

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: Colors.transparent,
                                    ),
                                    child: ExpansionTile(
                                      iconColor: const Color(0xFF00B4D8),
                                      collapsedIconColor: Colors.white54,
                                      tilePadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF00B4D8)
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_month_rounded,
                                          color: Color(0xFF00B4D8),
                                        ),
                                      ),
                                      title: Text(
                                        date,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '${presentes.length} Presentes  ·  ${ausentes.length} Ausentes',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.white60,
                                          ),
                                        ),
                                      ),
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            16,
                                            0,
                                            16,
                                            16,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const Divider(
                                                color: Colors.white12,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                'Alumnos Presentes (${presentes.length})',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.greenAccent,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (presentes.isEmpty)
                                                Text(
                                                  'Ningún alumno presente.',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: Colors.white38,
                                                  ),
                                                )
                                              else
                                                ...presentes.map(
                                                  (studentName) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .check_circle_rounded,
                                                          color: Colors
                                                              .greenAccent,
                                                          size: 16,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            studentName,
                                                            style:
                                                                GoogleFonts.inter(
                                                                  fontSize: 13,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Alumnos Ausentes (${ausentes.length})',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              if (ausentes.isEmpty)
                                                Text(
                                                  'Ningún alumno ausente.',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 13,
                                                    color: Colors.white38,
                                                  ),
                                                )
                                              else
                                                ...ausentes.map(
                                                  (studentName) => Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons.cancel_rounded,
                                                          color:
                                                              Colors.redAccent,
                                                          size: 16,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            studentName,
                                                            style:
                                                                GoogleFonts.inter(
                                                                  fontSize: 13,
                                                                  color: Colors
                                                                      .white70,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
