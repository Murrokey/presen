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
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  UserProfile? currentUser;
  bool isLoading = false;
  String errorMessage = '';

  bool get isAuthenticated => currentUser != null;

  bool get isCloudConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static Future<void> initialize() async {
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
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
      if (profile.savedCourse.isNotEmpty) {
        await prefs.setString('student_course', profile.savedCourse);
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
    required String role,
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

      final profile = UserProfile(
        id: userId,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
        createdAt: DateTime.now(),
      );

      if (isCloudConfigured) {
        await Supabase.instance.client
            .from('user_profiles')
            .upsert(profile.toJson());
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
      await Supabase.instance.client.from('attendance_sessions').insert({
        'class_name': session.className,
        'subject': session.subject,
        'code': session.code,
        'date': session.date.toIso8601String(),
        'students': session.students,
      });
    } catch (_) {}
  }

  List<Career> getDefaultCareers() {
    return [
      Career(id: '1', name: 'Desarrollo de Software'),
      Career(id: '2', name: 'Enfermería'),
      Career(id: '3', name: 'Diseño Gráfico'),
      Career(id: '4', name: 'Turismo'),
      Career(id: '5', name: 'Administración'),
    ];
  }

  List<Subject> getDefaultSubjects() {
    return [
      Subject(id: '1', name: 'Programación', careerId: '1'),
      Subject(id: '2', name: 'Base de Datos', careerId: '1'),
      Subject(id: '3', name: 'Matemáticas', careerId: '1'),
      Subject(id: '4', name: 'Literatura', careerId: '4'),
      Subject(id: '5', name: 'Práctica Profesional', careerId: '2'),
    ];
  }

  List<CourseClass> parseSavedClasses(List<String> entries) {
    return entries.map((e) => CourseClass.fromStorageEntry(e)).toList();
  }
}
