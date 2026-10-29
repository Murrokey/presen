import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:presen/services/supabase_service.dart';

void main() {
  test('Prueba completa de Registro, Logout, Login y Clases en SupabaseService', () async {
    SharedPreferences.setMockInitialValues({});

    final service = SupabaseService();
    print('1. ¿Arranca logueado?: ${service.isAuthenticated}');

    final registroOk = await service.registerUser(
      email: 'nahuel@escuela.com',
      password: '123456',
      firstName: 'Nahuel',
      lastName: 'Gomez',
    );
    print('2. ¿Se registró bien?: $registroOk');
    print(
      '   Usuario actual: ${service.currentUser?.fullName} | Rol por defecto: ${service.currentUser?.role}',
    );

    await service.logoutUser();
    print(
      '3. Después de logoutUser(), ¿sigue logueado?: ${service.isAuthenticated}',
    );

    final loginMal = await service.loginUser(
      email: 'nahuel@escuela.com',
      password: 'clave_equivocada',
    );
    print(
      '4. Intento con clave mala -> ¿Entró?: $loginMal | Error: ${service.errorMessage}',
    );

    final loginBien = await service.loginUser(
      email: 'nahuel@escuela.com',
      password: '123456',
    );
    print(
      '5. Intento con clave correcta -> ¿Entró?: $loginBien | Bienvenido: ${service.currentUser?.fullName}',
    );

    final clases = service.parseSavedClasses([
      '2do - 1ra|Desarrollo de Software|Programación',
    ]);
    print(
      '6. Clase reconstruida con Modelo 4: Curso="${clases.first.fullCourseName}", Materia="${clases.first.subjectName}"',
    );

    expect(service.isAuthenticated, true);
  });
}
