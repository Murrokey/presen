# Presen

Aplicación móvil de **control de asistencia por proximidad** desarrollada en **Flutter** con backend relacional en **Supabase (PostgreSQL + Auth)** y comunicación punto a punto sin internet mediante **Google Nearby Connections (Bluetooth / Wi-Fi Direct)**.

---

## Arquitectura del Proyecto

```text
lib/
├── main.dart                     # Inicialización, MultiProvider, Material 3 y onGenerateRoute
├── models/                       # 6 modelos tipados con serialización fromJson / toJson
│   ├── attendance_session.dart
│   ├── career.dart
│   ├── course.dart
│   ├── course_class.dart
│   ├── subject.dart
│   └── user_profile.dart
├── services/                     # Lógica de negocio desacoplada con ChangeNotifier
│   ├── nearby_service.dart       # Motor P2P (P2P_CLUSTER), cola secuencial y protocolo REQ/ACK/CANC
│   └── supabase_service.dart     # Auth, consultas relacionales (JOIN) y caché offline
└── screens/                      # Vistas diferenciadas por rol (Alumno y Profesor)
    ├── login_screen.dart
    ├── student_screen.dart
    ├── student_history_screen.dart
    ├── teacher_screen.dart
    ├── roster_screen.dart
    └── history_screen.dart
supabase/
└── migrations/                   # Migraciones SQL versionadas del esquema relacional
    ├── 001_initial_schema.sql
    └── 002_normalized_schema.sql
```

---

## Base de Datos Relacional (8 Tablas Normalizadas)

1. `user_profiles` (`1:1` con `auth.users`): perfil y rol (`student` / `teacher`).
2. `careers`: catálogo de carreras institucionales.
3. `subjects` (`1:N` con `careers`): materias por carrera y año.
4. `courses` (`1:N` con `careers`): año, división y ciclo lectivo.
5. `course_enrollments` (`N:M` entre `courses` y `user_profiles`): inscripción de alumnos a cursos.
6. `course_classes` (`1:N` con `courses`, `subjects` y `user_profiles`): comisiones asignadas a docentes.
7. `attendance_sessions` (`1:N` con `course_classes`): clases tomadas fecha por fecha.
8. `attendance_records` (`N:M` entre `attendance_sessions` y `user_profiles`): presentes y ausentes por sesión.

---

## Adaptación de la Rúbrica (Django → Flutter + Supabase)

| Concepto en Django | Equivalente implementado en Presen |
| :--- | :--- |
| Apps diferenciadas | Separación modular (`models/`, `services/`, `screens/`) y módulos funcionales **Alumno** y **Profesor** |
| `settings.py` | `pubspec.yaml`, `AndroidManifest.xml`, `build.gradle.kts` y `SupabaseService.initialize()` en `main.dart` |
| ORM y Migraciones | Scripts SQL versionados en `supabase/migrations/` (`001` → `002`) + mapeo tipado en Dart |
| Modelos y Relaciones | 8 tablas PostgreSQL (`1:1`, `1:N`, `N:M`) y 6 modelos en `lib/models/` con consultas `JOIN` y buscadores en vivo |
| Vistas (`request-response`) | 6 `StatefulWidget` con flujo asíncrono REST/PostgREST + protocolo P2P (`REQ\|` → `ACK\|` / `CANC\|`) |
| URLs nombradas | Enrutador centralizado `onGenerateRoute` en `lib/main.dart` con paso de argumentos tipados |
| Lógica de negocio separada | Patrón `Provider` (`SupabaseService` y `NearbyService`) |
| Templates y Partials | `ThemeData` global, `ListView.builder`, renderizado condicional y widgets constructores reutilizables |
| Formularios y validación | `Form`, `GlobalKey<FormState>` y `TextFormField` con `validator` |
| Autenticación y vistas protegidas | Supabase Auth (`signUp`, `signInWithPassword`, `signOut`) + ruteo automático por rol desde BD |
| Estilos y estáticos | Material 3 oscuro (`#12121A`), `GoogleFonts`, `assets/icon/` e ícono nativo adaptable |

---

## Ejecución local

```powershell
flutter pub get
flutter run
```
