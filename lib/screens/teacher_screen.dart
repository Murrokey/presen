import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/course_class.dart';
import '../models/subject.dart';
import '../services/nearby_service.dart';
import '../services/supabase_service.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key});

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarAnimationController;

  List<CourseClass> _savedClasses = [];
  CourseClass? _activeClass;
  bool _isLoadingClasses = false;

  @override
  void initState() {
    super.initState();
    _radarAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeacherClasses();
    });
  }

  @override
  void dispose() {
    _radarAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherClasses() async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final user = supabaseService.currentUser;

    setState(() => _isLoadingClasses = true);

    await supabaseService.fetchCatalogData();

    List<CourseClass> loadedClasses = [];

    if (supabaseService.isCloudConfigured && user != null) {
      try {
        final data = await Supabase.instance.client
            .from('course_classes')
            .select('*, courses(*, careers(*)), subjects(*)')
            .eq('teacher_id', user.id)
            .order('created_at', ascending: false);

        loadedClasses = (data as List)
            .map((item) => CourseClass.fromJson(item))
            .toList();
      } catch (_) {}
    }

    if (loadedClasses.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final entries = prefs.getStringList('teacher_saved_classes') ?? [];
      loadedClasses = supabaseService.parseSavedClasses(entries);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final entries = loadedClasses.map((c) => c.storageEntry).toList();
      await prefs.setStringList('teacher_saved_classes', entries);
    }

    if (mounted) {
      setState(() {
        _savedClasses = loadedClasses;
        _isLoadingClasses = false;
      });
    }
  }

  Future<void> _createNewClass({
    required String careerId,
    required String careerName,
    required int yearLevel,
    required String division,
    required Subject subject,
  }) async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final user = supabaseService.currentUser;
    final courseName = '${yearLevel}ro - $division $careerName';

    CourseClass newClass = CourseClass(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      courseId: '',
      subjectId: subject.id,
      teacherId: user?.id,
      createdAt: DateTime.now(),
      courseName: courseName,
      subjectName: subject.name,
    );

    if (supabaseService.isCloudConfigured && user != null) {
      try {
        final courseData = await Supabase.instance.client
            .from('courses')
            .select('id')
            .eq('career_id', careerId)
            .eq('year_level', yearLevel)
            .eq('division', division)
            .maybeSingle();

        if (courseData != null) {
          final courseId = courseData['id'].toString();

          final inserted = await Supabase.instance.client
              .from('course_classes')
              .upsert({
                'course_id': courseId,
                'subject_id': subject.id,
                'teacher_id': user.id,
              }, onConflict: 'course_id,subject_id')
              .select('*, courses(*, careers(*)), subjects(*)')
              .single();

          newClass = CourseClass.fromJson(inserted);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar en Supabase: $e')),
          );
        }
      }
    }

    final exists = _savedClasses.any(
      (c) =>
          c.courseName == newClass.courseName &&
          c.subjectName == newClass.subjectName,
    );

    if (!exists) {
      setState(() {
        _savedClasses.insert(0, newClass);
      });
      final prefs = await SharedPreferences.getInstance();
      final entries = _savedClasses.map((c) => c.storageEntry).toList();
      await prefs.setStringList('teacher_saved_classes', entries);
    }
  }

  Future<void> _removeClass(CourseClass courseClass) async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );

    if (supabaseService.isCloudConfigured &&
        !courseClass.id.startsWith('local_')) {
      try {
        await Supabase.instance.client
            .from('course_classes')
            .delete()
            .eq('id', courseClass.id);
      } catch (_) {}
    }

    setState(() {
      _savedClasses.removeWhere((c) => c.id == courseClass.id);
    });

    final prefs = await SharedPreferences.getInstance();
    final entries = _savedClasses.map((c) => c.storageEntry).toList();
    await prefs.setStringList('teacher_saved_classes', entries);
  }

  Future<void> _startClassAttendance(CourseClass courseClass) async {
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    final nearbyService = Provider.of<NearbyService>(context, listen: false);
    final user = supabaseService.currentUser;

    setState(() {
      _activeClass = courseClass;
      _radarAnimationController.repeat();
    });

    await nearbyService.startDiscovering(
      teacherFirstName: user?.firstName ?? 'Docente',
      teacherLastName: user?.lastName ?? '',
      course: courseClass.courseName ?? '',
      subject: courseClass.subjectName ?? '',
    );
  }

  Future<void> _finishAttendance() async {
    final activeClass = _activeClass;
    if (activeClass == null) return;

    final nearbyService = Provider.of<NearbyService>(context, listen: false);
    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );

    final presentNames = nearbyService.presentStudents
        .map((s) => s.name.trim())
        .toList();

    final prefs = await SharedPreferences.getInstance();
    final rosterKey =
        'roster_${activeClass.courseName}_${activeClass.subjectName}_UNIVERSAL';
    final roster = prefs.getStringList(rosterKey) ?? [];

    for (final name in presentNames) {
      if (!roster.contains(name)) {
        roster.add(name);
      }
    }
    roster.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await prefs.setStringList(rosterKey, roster);

    final historyList = prefs.getStringList('attendance_history') ?? [];
    final now = DateTime.now();
    final localRecord = {
      'id': now.millisecondsSinceEpoch.toString(),
      'class_id': activeClass.id,
      'className': activeClass.courseName ?? '',
      'subject': activeClass.subjectName ?? '',
      'code': 'UNIVERSAL',
      'date': now.toIso8601String(),
      'created_at': now.toIso8601String(),
      'students': presentNames,
    };
    historyList.add(jsonEncode(localRecord));
    await prefs.setStringList('attendance_history', historyList);

    if (supabaseService.isCloudConfigured &&
        !activeClass.id.startsWith('local_')) {
      try {
        final sessionRow = await Supabase.instance.client
            .from('attendance_sessions')
            .insert({
              'class_id': activeClass.id,
              'code': 'UNIVERSAL',
              'session_date': now.toIso8601String(),
            })
            .select('id')
            .single();

        final sessionId = sessionRow['id'].toString();

        if (activeClass.courseId.isNotEmpty) {
          final enrolledData = await Supabase.instance.client
              .from('course_enrollments')
              .select('student_id, user_profiles(first_name, last_name)')
              .eq('course_id', activeClass.courseId);

          final List<Map<String, dynamic>> recordsToInsert = [];

          for (final item in (enrolledData as List)) {
            final studentId = item['student_id'].toString();
            final profile = item['user_profiles'];
            final fullName =
                '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'
                    .trim();

            final wasPresent = presentNames.any(
              (p) => p.toLowerCase() == fullName.toLowerCase(),
            );

            recordsToInsert.add({
              'session_id': sessionId,
              'student_id': studentId,
              'is_present': wasPresent,
            });
          }

          if (recordsToInsert.isNotEmpty) {
            await Supabase.instance.client
                .from('attendance_records')
                .upsert(recordsToInsert);
          }
        }
      } catch (_) {}
    }

    await nearbyService.stopDiscovering();

    if (mounted) {
      setState(() {
        _activeClass = null;
        _radarAnimationController.stop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearbyService = Provider.of<NearbyService>(context);
    final supabaseService = Provider.of<SupabaseService>(context);
    final user = supabaseService.currentUser;

    return PopScope(
      canPop: !nearbyService.isDiscovering,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && nearbyService.isDiscovering) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Finaliza o cancela la asistencia antes de salir.'),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF12121A),
        floatingActionButton: nearbyService.isDiscovering
            ? FloatingActionButton.extended(
                onPressed: () => _showManualAddDialog(nearbyService),
                backgroundColor: const Color(0xFF00B4D8),
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  'Agregar',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : FloatingActionButton(
                onPressed: () => _showAddClassDialog(supabaseService),
                backgroundColor: const Color(0xFF00B4D8),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(user, supabaseService, nearbyService),
                const SizedBox(height: 20),
                Expanded(
                  child: nearbyService.isDiscovering
                      ? _buildActiveAttendanceState(nearbyService)
                      : _buildClassesListState(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(
    user,
    SupabaseService supabaseService,
    NearbyService nearbyService,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola, ${user?.firstName ?? 'Profesor'}!',
                style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B4D8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF00B4D8).withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'Modo Profesor',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF00B4D8),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!nearbyService.isDiscovering)
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

  Widget _buildClassesListState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Mis Clases y Comisiones',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Toca una tarjeta para ver sus estadísticas o presiona Iniciar para tomar asistencia.',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.white54),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoadingClasses
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
                )
              : _savedClasses.isEmpty
              ? Center(
                  child: Text(
                    'Aún no tienes clases guardadas.\nToca el botón + para agregar una comisión.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(color: Colors.white54),
                  ),
                )
              : ListView.builder(
                  itemCount: _savedClasses.length,
                  itemBuilder: (context, index) {
                    final courseClass = _savedClasses[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/teacher-stats',
                          arguments: courseClass,
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B4D8)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    color: Color(0xFF00B4D8),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        courseClass.courseName ?? 'Curso',
                                        style: GoogleFonts.outfit(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        courseClass.subjectName ?? 'Materia',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: const Color(0xFF00B4D8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.bar_chart_rounded,
                                  color: Colors.greenAccent,
                                  size: 22,
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white30,
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  tooltip: 'Eliminar comisión',
                                  onPressed: () =>
                                      _confirmRemoveClass(courseClass),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () =>
                                      _startClassAttendance(courseClass),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00B4D8)
                                        .withValues(alpha: 0.2),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Color(0xFF00B4D8),
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Iniciar',
                                    style: TextStyle(
                                      color: Color(0xFF00B4D8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActiveAttendanceState(NearbyService nearbyService) {
    final visibleStudents =
        nearbyService.presentStudents.map((s) => s.name).toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_activeClass?.courseName ?? ''} (${_activeClass?.subjectName ?? ''})',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  await nearbyService.cancelDiscovery();
                  if (mounted) {
                    setState(() {
                      _activeClass = null;
                      _radarAnimationController.stop();
                    });
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _finishAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Finalizar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF00B4D8).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00B4D8).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              RotationTransition(
                turns: _radarAnimationController,
                child: const Icon(
                  Icons.radar_rounded,
                  color: Color(0xFF00B4D8),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Buscando alumnos por proximidad...',
                  style: GoogleFonts.inter(fontSize: 15, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Alumnos Presentes (${visibleStudents.length})',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: visibleStudents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_off_rounded,
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Aún no hay alumnos detectados.',
                        style: GoogleFonts.inter(color: Colors.white54),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: visibleStudents.length,
                  itemBuilder: (context, index) {
                    final studentName = visibleStudents[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.greenAccent.withValues(
                            alpha: 0.2,
                          ),
                          child: Text(
                            studentName.isNotEmpty
                                ? studentName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          studentName,
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          'Presente',
                          style: GoogleFonts.inter(
                            color: Colors.greenAccent,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.greenAccent,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddClassDialog(SupabaseService supabaseService) {
    if (supabaseService.careers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cargando catálogo desde Supabase, intenta en un segundo.',
          ),
        ),
      );
      supabaseService.fetchCatalogData();
      return;
    }

    String selectedCareerId = supabaseService.careers.first.id;
    String selectedCareerName = supabaseService.careers.first.name;
    int selectedYearLevel = 1;
    String selectedDivision = '1ra';
    Subject? selectedSubject;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredSubjects = supabaseService.subjects
              .where(
                (s) =>
                    s.careerId == selectedCareerId &&
                    s.yearLevel == selectedYearLevel,
              )
              .toList();

          if (selectedSubject == null ||
              !filteredSubjects.any((s) => s.id == selectedSubject!.id)) {
            selectedSubject = filteredSubjects.isNotEmpty
                ? filteredSubjects.first
                : null;
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Text(
              'Agregar Nueva Comisión',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogDropdown<String>(
                    value: selectedCareerId,
                    label: 'Carrera',
                    icon: Icons.account_balance_rounded,
                    items: supabaseService.careers.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final careerObj = supabaseService.careers.firstWhere(
                          (c) => c.id == val,
                        );
                        setDialogState(() {
                          selectedCareerId = val;
                          selectedCareerName = careerObj.name;
                          selectedSubject = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDialogDropdown<int>(
                          value: selectedYearLevel,
                          label: 'Año',
                          icon: Icons.looks_one_rounded,
                          items: const [
                            DropdownMenuItem(value: 1, child: Text('1ro')),
                            DropdownMenuItem(value: 2, child: Text('2do')),
                            DropdownMenuItem(value: 3, child: Text('3ro')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedYearLevel = val;
                                selectedSubject = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildDialogDropdown<String>(
                          value: selectedDivision,
                          label: 'División',
                          icon: Icons.class_outlined,
                          items: const [
                            DropdownMenuItem(value: '1ra', child: Text('1ra')),
                            DropdownMenuItem(value: '2da', child: Text('2da')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedDivision = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (filteredSubjects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Text(
                        'No hay materias cargadas en Supabase para este año y carrera.',
                        style: GoogleFonts.inter(
                          color: Colors.orangeAccent,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    _buildDialogDropdown<String>(
                      value: selectedSubject!.id,
                      label: 'Materia',
                      icon: Icons.menu_book_rounded,
                      items: filteredSubjects.map((s) {
                        return DropdownMenuItem<String>(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedSubject = filteredSubjects.firstWhere(
                              (s) => s.id == val,
                            );
                          });
                        }
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
              ElevatedButton(
                onPressed: selectedSubject == null
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);
                        await _createNewClass(
                          careerId: selectedCareerId,
                          careerName: selectedCareerName,
                          yearLevel: selectedYearLevel,
                          division: selectedDivision,
                          subject: selectedSubject!,
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                ),
                child: const Text(
                  'Guardar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogDropdown<T>({
    required T value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        isExpanded: true,
        dropdownColor: const Color(0xFF1A1A2E),
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  void _confirmRemoveClass(CourseClass courseClass) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          '¿Eliminar comisión?',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Text(
          '¿Deseas quitar "${courseClass.fullTitle}" de tu lista de clases?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _removeClass(courseClass);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualAddDialog(NearbyService nearbyService) {
    final formKey = GlobalKey<FormState>();
    final manualNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          'Agregar Alumno Manualmente',
          style: GoogleFonts.outfit(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: manualNameController,
            style: const TextStyle(color: Colors.white),
            validator: (val) {
              if (val == null || val.trim().length < 3) {
                return 'Ingresa nombre y apellido válidos';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Nombre y apellido del alumno',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                nearbyService.addStudentManually(
                  manualNameController.text.trim(),
                );
                Navigator.pop(dialogContext);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B4D8),
            ),
            child: const Text('Agregar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
