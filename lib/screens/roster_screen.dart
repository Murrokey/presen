import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/course_class.dart';
import '../services/supabase_service.dart';

class RosterScreen extends StatefulWidget {
  final CourseClass courseClass;

  const RosterScreen({super.key, required this.courseClass});

  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<String> _roster = [];
  int _totalSessions = 0;
  Map<String, int> _studentPresents = {};
  String _searchQuery = '';
  bool _isLoading = true;

  String get _rosterKey =>
      'roster_${widget.courseClass.courseName}_${widget.courseClass.subjectName}_UNIVERSAL';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStatsData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStatsData() async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    setState(() => _isLoading = true);

    final Set<String> studentsSet = {};
    final Map<String, int> presentsCount = {};
    int sessionsCount = 0;

    if (supabaseService.isCloudConfigured &&
        !widget.courseClass.id.startsWith('local_')) {
      try {
        if (widget.courseClass.courseId.isNotEmpty) {
          final enrolledData = await Supabase.instance.client
              .from('course_enrollments')
              .select('user_profiles(first_name, last_name)')
              .eq('course_id', widget.courseClass.courseId);

          for (final item in (enrolledData as List)) {
            final p = item['user_profiles'];
            final fullName =
                '${p?['first_name'] ?? ''} ${p?['last_name'] ?? ''}'.trim();
            if (fullName.isNotEmpty) {
              studentsSet.add(fullName);
              presentsCount[fullName] = 0;
            }
          }
        }

        final sessionsData = await Supabase.instance.client
            .from('attendance_sessions')
            .select(
              'id, attendance_records(is_present, user_profiles(first_name, last_name))',
            )
            .eq('class_id', widget.courseClass.id);

        final sessionsList = sessionsData as List;
        sessionsCount = sessionsList.length;

        for (final session in sessionsList) {
          final records = session['attendance_records'] as List? ?? [];
          for (final r in records) {
            final p = r['user_profiles'];
            final fullName =
                '${p?['first_name'] ?? ''} ${p?['last_name'] ?? ''}'.trim();
            if (fullName.isNotEmpty) {
              studentsSet.add(fullName);
              if (r['is_present'] == true) {
                presentsCount[fullName] = (presentsCount[fullName] ?? 0) + 1;
              } else {
                presentsCount.putIfAbsent(fullName, () => 0);
              }
            }
          }
        }
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    final localRoster = prefs.getStringList(_rosterKey) ?? [];
    for (final s in localRoster) {
      studentsSet.add(s);
      presentsCount.putIfAbsent(s, () => 0);
    }

    if (sessionsCount == 0) {
      final historyList = prefs.getStringList('attendance_history') ?? [];
      for (final item in historyList) {
        try {
          final record = jsonDecode(item) as Map<String, dynamic>;
          if (record['className'] == widget.courseClass.courseName &&
              record['subject'] == widget.courseClass.subjectName) {
            sessionsCount++;
            final presents = List<String>.from(record['students'] ?? []);
            for (final s in presents) {
              studentsSet.add(s);
              presentsCount[s] = (presentsCount[s] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }
    }

    final sortedRoster = studentsSet.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (mounted) {
      setState(() {
        _roster = sortedRoster;
        _totalSessions = sessionsCount;
        _studentPresents = presentsCount;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeStudent(String studentName) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Text(
              'Eliminar Alumno',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            content: Text(
              '¿Deseas quitar a "$studentName" de la lista de esta comisión?',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _roster.remove(studentName);
        _studentPresents.remove(studentName);
      });
      await prefs.setStringList(_rosterKey, _roster);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRoster = _roster
        .where(
          (student) =>
              student.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF12121A),
      appBar: AppBar(
        title: Text(
          'Lista de Alumnos',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.courseClass.courseName ?? 'Curso',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.courseClass.subjectName ?? 'Materia',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFF00B4D8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Total Clases',
                            '$_totalSessions',
                            Icons.calendar_today_rounded,
                          ),
                          _buildStatItem(
                            'Alumnos',
                            '${_roster.length}',
                            Icons.groups_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/teacher-history',
                          arguments: widget.courseClass,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00B4D8),
                        side: BorderSide(
                          color: const Color(0xFF00B4D8).withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 20),
                      label: Text(
                        'Ver Clases Fecha por Fecha',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Buscar alumno por nombre...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  color: Colors.white54,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Estadísticas por Alumno',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredRoster.isEmpty
                          ? Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'Aún no hay alumnos registrados en esta materia.'
                                    : 'No se encontraron alumnos con "$_searchQuery".',
                                style: GoogleFonts.inter(color: Colors.white54),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredRoster.length,
                              itemBuilder: (context, index) {
                                final student = filteredRoster[index];
                                final presents = _studentPresents[student] ?? 0;
                                final absents = (_totalSessions - presents)
                                    .clamp(0, _totalSessions);

                                double percentage = 0;
                                if (_totalSessions > 0) {
                                  percentage =
                                      (presents / _totalSessions) * 100;
                                }

                                Color percentColor = Colors.greenAccent;
                                if (percentage < 50) {
                                  percentColor = Colors.redAccent;
                                } else if (percentage < 75) {
                                  percentColor = Colors.orangeAccent;
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              student,
                                              style: GoogleFonts.outfit(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.white54,
                                              size: 20,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            tooltip: 'Eliminar alumno',
                                            onPressed: () =>
                                                _removeStudent(student),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildMiniStat(
                                            'Presentes',
                                            '$presents',
                                            Colors.greenAccent,
                                          ),
                                          _buildMiniStat(
                                            'Ausentes',
                                            '$absents',
                                            Colors.redAccent,
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Asistencia',
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: Colors.white54,
                                                ),
                                              ),
                                              Text(
                                                '${percentage.toStringAsFixed(1)}%',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                  color: percentColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF00B4D8), size: 30),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        ),
        Row(
          children: [
            Icon(Icons.circle, size: 8, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
