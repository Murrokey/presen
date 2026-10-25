CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'student',
  saved_course TEXT DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS careers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT UNIQUE NOT NULL,
  duration_years INTEGER NOT NULL DEFAULT 3,
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  career_id UUID NOT NULL REFERENCES careers(id) ON DELETE CASCADE,
  weekly_hours INTEGER NOT NULL DEFAULT 4
);

CREATE TABLE IF NOT EXISTS course_classes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_year TEXT NOT NULL,
  career_name TEXT NOT NULL,
  subject_name TEXT NOT NULL,
  teacher_id UUID REFERENCES user_profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS attendance_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_name TEXT NOT NULL,
  subject TEXT NOT NULL,
  code TEXT NOT NULL DEFAULT 'UNIVERSAL',
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  students JSONB NOT NULL DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS attendance_records (
  session_id UUID NOT NULL REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  student_profile_id UUID NOT NULL REFERENCES user_profiles(id) ON DELETE CASCADE,
  is_present BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (session_id, student_profile_id)
);