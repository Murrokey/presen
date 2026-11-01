import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/subject.dart';
import '../services/supabase_service.dart';

class StudentHistoryScreen extends StatefulWidget {
  final Subject subject;

  const StudentHistoryScreen({super.key, required this.subject});

  @override
  State<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends State<StudentHistoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _records = [];
  int _totalClasses = 0;
  int _attendedClasses = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final user = supabaseService.currentUser;

    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    List<Map<String, dynamic>> loadedRecords = [];

    if (supabaseService.isCloudConfigured) {
      try {
        final data = await Supabase.instance.client
            .from('attendance_records')
            .select(
              'is_present, recorded_at, attendance_sessions!inner(class_id, session_date, course_classes!inner(subject_id))',
            )
            .eq('student_id', user.id)
            .eq(
              'attendance_sessions.course_classes.subject_id',
              widget.subject.id,
            )
            .order('recorded_at', ascending: false);

        for (var item in (data as List)) {
          final session = item['attendance_sessions'];
          loadedRecords.add({
            'date': session['session_date'] ?? item['recorded_at'],
            'is_present': item['is_present'] ?? true,
          });
        }
      } catch (_) {}
    }

    if (loadedRecords.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final localHistory = prefs.getStringList('attendance_history') ?? [];

      for (var raw in localHistory) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          if (map['subject'] == widget.subject.name) {
            final students = List<String>.from(map['students'] ?? []);
            final wasPresent = students.any(
              (s) => s.toLowerCase() == user.fullName.toLowerCase(),
            );
            loadedRecords.add({
              'date': map['date'] ?? '',
              'is_present': wasPresent,
            });
          }
        } catch (_) {}
      }
    }

    int attended = loadedRecords.where((r) => r['is_present'] == true).length;

    if (mounted) {
      setState(() {
        _records = loadedRecords;
        _totalClasses = loadedRecords.length;
        _attendedClasses = attended;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double percentage = _totalClasses > 0
        ? (_attendedClasses / _totalClasses) * 100
        : 0.0;

    Color percentageColor = Colors.greenAccent;
    if (percentage < 50.0) {
      percentageColor = Colors.redAccent;
    } else if (percentage < 75.0) {
      percentageColor = Colors.orangeAccent;
    }

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
        title: Text(
          widget.subject.name,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
              )
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatsCard(percentage, percentageColor),
                    const SizedBox(height: 24),
                    Text(
                      'Historial de Clases',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _records.isEmpty
                          ? Center(
                              child: Text(
                                'Aún no hay clases registradas para esta materia.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(color: Colors.white54),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _records.length,
                              itemBuilder: (context, index) {
                                final record = _records[index];
                                final isPresent = record['is_present'] == true;
                                final rawDate =
                                    record['date']?.toString() ?? '';

                                String formattedDate = rawDate;
                                final dt = DateTime.tryParse(rawDate);
                                if (dt != null) {
                                  final day = dt.day.toString().padLeft(2, '0');
                                  final month = dt.month.toString().padLeft(
                                    2,
                                    '0',
                                  );
                                  final hour = dt.hour.toString().padLeft(
                                    2,
                                    '0',
                                  );
                                  final minute = dt.minute.toString().padLeft(
                                    2,
                                    '0',
                                  );
                                  formattedDate =
                                      '$day/$month/${dt.year} - $hour:$minute';
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isPresent
                                          ? Colors.greenAccent.withValues(
                                              alpha: 0.2,
                                            )
                                          : Colors.redAccent.withValues(
                                              alpha: 0.2,
                                            ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 18,
                                            color: Colors.white.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            formattedDate,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPresent
                                              ? Colors.greenAccent.withValues(
                                                  alpha: 0.15,
                                                )
                                              : Colors.redAccent.withValues(
                                                  alpha: 0.15,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPresent
                                                  ? Icons.check_circle_rounded
                                                  : Icons.cancel_rounded,
                                              size: 14,
                                              color: isPresent
                                                  ? Colors.greenAccent
                                                  : Colors.redAccent,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              isPresent
                                                  ? 'Presente'
                                                  : 'Ausente',
                                              style: GoogleFonts.inter(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: isPresent
                                                    ? Colors.greenAccent
                                                    : Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
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

  Widget _buildStatsCard(double percentage, Color percentageColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('Total Clases', '$_totalClasses'),
          Container(
            height: 40,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          _buildStatColumn('Asistencias', '$_attendedClasses'),
          Container(
            height: 40,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Column(
            children: [
              Text(
                '${percentage.toStringAsFixed(1)}%',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: percentageColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Porcentaje',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white54),
        ),
      ],
    );
  }
}
