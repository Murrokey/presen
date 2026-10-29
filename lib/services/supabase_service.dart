import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_session.dart';
import '../models/career.dart';
import '../models/course_class.dart';
import '../models/subject.dart';
import '../models/user_profile.dart';

class SupabaseService extends ChangeNotifier {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mgxmwvfngwsicaqrgjoi.supabase.co',
  );
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_HRvd-p8a0S5dZHWuAM9pVg_i7vvryOQ',
  );

  UserProfile? currentUser;
  bool isLoading = false;
  String errorMessage = '';

  List<Career> careers = [];
  List<Subject> subjects = [];
  List<String> divisions = ['1ro - 1ra', '2do - 1ra', '3ro - 1ra'];

  bool get isAuthenticated => currentUser != null;

  bool get isCloudConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabasePublishableKey,
      );
    }
  }

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserJson = prefs.getString('current_user_profile');
    if (savedUserJson != null && savedUserJson.isNotEmpty) {
      currentUser = UserProfile.fromJson(jsonDecode(savedUserJson));
      notifyListeners();
    }
  }

  Future<void> logoutUser() async {
    if (isCloudConfigured) {
      await Supabase.instance.client.auth.signOut();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_profile');
    currentUser = null;
    notifyListeners();
  }

  Future<void> _saveUserLocally(UserProfile profile, {String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_profile', jsonEncode(profile.toJson()));
    await _syncRolePrefs(profile);

    if (password != null) {
      final usersList = prefs.getStringList('registered_users') ?? [];
      usersList.removeWhere((item) {
        final map = jsonDecode(item) as Map<String, dynamic>;
        return map['email'] == profile.email;
      });
      final mapWithPass = profile.toJson()..['password'] = password;
      usersList.add(jsonEncode(mapWithPass));
      await prefs.setStringList('registered_users', usersList);
    }
  }

  Future<void> _syncRolePrefs(UserProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    if (profile.role == 'student') {
      await prefs.setString('student_name', profile.fullName);
      if (profile.enrolledCourseName != null &&
          profile.enrolledCourseName!.isNotEmpty) {
        await prefs.setString('student_course', profile.enrolledCourseName!);
      }
    } else {
      await prefs.setString('teacher_first_name', profile.firstName);
      await prefs.setString('teacher_last_name', profile.lastName);
    }
  }

  Future<bool> registerUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String role = 'student',
    int? yearLevel,
    String? division,
    String? careerName,
  }) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      String userId = 'local_${DateTime.now().millisecondsSinceEpoch}';

      if (isCloudConfigured) {
        final authResponse = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (authResponse.user != null) {
          userId = authResponse.user!.id;
        }
      }

      final courseDisplay =
          (yearLevel != null && division != null && careerName != null)
          ? '${yearLevel}ro - $division $careerName'
          : '';

      final profile = UserProfile(
        id: userId,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
        enrolledCourseName: courseDisplay,
        createdAt: DateTime.now(),
      );

      if (isCloudConfigured) {
        await Supabase.instance.client
            .from('user_profiles')
            .upsert(profile.toJson());

        // Inscribir al alumno en course_enrollments de forma EXACTA
        if (role == 'student' &&
            yearLevel != null &&
            division != null &&
            careerName != null) {
          // Buscamos primero la carrera para tener su id
          final careerData = await Supabase.instance.client
              .from('careers')
              .select('id')
              .eq('name', careerName)
              .maybeSingle();
          if (careerData != null) {
            final careerId = careerData['id'];
            // Buscamos el curso EXACTO con las 3 coincidencias
            final courseData = await Supabase.instance.client
                .from('courses')
                .select('id')
                .eq('career_id', careerId)
                .eq('year_level', yearLevel)
                .eq('division', division)
                .maybeSingle();
            if (courseData != null) {
              await Supabase.instance.client.from('course_enrollments').upsert({
                'student_id': userId,
                'course_id': courseData['id'],
              });
            } else {
              throw Exception(
                'No se encontró el curso exacto: $yearLevel $division para $careerName',
              );
            }
          }
        }
      }

      await _saveUserLocally(profile, password: password);
      currentUser = profile;
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'No se pudo completar el registro: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginUser({
    required String email,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      if (isCloudConfigured) {
        final authResponse = await Supabase.instance.client.auth
            .signInWithPassword(email: email.trim(), password: password);
        final userId = authResponse.user?.id;
        if (userId != null) {
          final data = await Supabase.instance.client
              .from('user_profiles')
              .select()
              .eq('id', userId)
              .maybeSingle();
          if (data != null) {
            currentUser = UserProfile.fromJson(data);
            await _saveUserLocally(currentUser!);
            isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final usersList = prefs.getStringList('registered_users') ?? [];
      for (final item in usersList) {
        final map = jsonDecode(item) as Map<String, dynamic>;
        if (map['email'] == email.trim() && map['password'] == password) {
          currentUser = UserProfile.fromJson(map);
          await prefs.setString(
            'current_user_profile',
            jsonEncode(currentUser!.toJson()),
          );
          await _syncRolePrefs(currentUser!);
          isLoading = false;
          notifyListeners();
          return true;
        }
      }

      errorMessage = 'Correo o contraseña incorrectos.';
      isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'Error al iniciar sesión: $e';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> syncAttendanceSession(AttendanceSession session) async {
    if (!isCloudConfigured) return;
    try {
      await Supabase.instance.client
          .from('attendance_sessions')
          .insert(session.toJson());
    } catch (_) {}
  }

  Future<void> fetchCatalogData() async {
    if (!isCloudConfigured) return;
    try {
      final careersData = await Supabase.instance.client
          .from('careers')
          .select()
          .order('name');

      careers = (careersData as List)
          .map((item) => Career.fromJson(item))
          .toList();

      final subjectsData = await Supabase.instance.client
          .from('subjects')
          .select()
          .order('name');

      subjects = (subjectsData as List)
          .map((item) => Subject.fromJson(item))
          .toList();

      notifyListeners();
    } catch (e) {
      errorMessage = 'Error al cargar datos de Supabase: $e';
      notifyListeners();
    }
  }

  List<CourseClass> parseSavedClasses(List<String> entries) {
    return entries.map((e) => CourseClass.fromStorageEntry(e)).toList();
  }
}
