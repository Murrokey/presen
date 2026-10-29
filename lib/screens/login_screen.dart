import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  bool _isRegisterMode = false;
  int _selectedYearLevel = 1;
  String _selectedDivision = '1ra';
  String? _selectedCareerName;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final supabaseService = Provider.of<SupabaseService>(
        context,
        listen: false,
      );
      supabaseService.fetchCatalogData();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final supabaseService = Provider.of<SupabaseService>(
      context,
      listen: false,
    );
    bool success = false;

    if (_isRegisterMode) {
      success = await supabaseService.registerUser(
        email: _emailController.text,
        password: _passwordController.text,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        yearLevel: _selectedYearLevel,
        division: _selectedDivision,
        careerName: _selectedCareerName,
      );
    } else {
      success = await supabaseService.loginUser(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }

    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required String label,
    required IconData icon,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        items: items,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        dropdownColor: const Color(0xFF1A1A2E),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supabaseService = Provider.of<SupabaseService>(context);

    final careerItems = supabaseService.careers.isNotEmpty
        ? supabaseService.careers.map((c) {
            return DropdownMenuItem<String>(
              value: c.name,
              child: Text(c.name, overflow: TextOverflow.ellipsis),
            );
          }).toList()
        : [
            const DropdownMenuItem<String>(
              value: 'Desarrollo de Software',
              child: Text('Desarrollo de Software'),
            ),
          ];

    if (_selectedCareerName == null && careerItems.isNotEmpty) {
      _selectedCareerName = careerItems.first.value;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.school_rounded,
                    size: 72,
                    color: Color(0xFF6C63FF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Presen',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegisterMode
                        ? 'Crea tu cuenta institucional'
                        : 'Inicia sesión para continuar',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (supabaseService.errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        supabaseService.errorMessage,
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_isRegisterMode) ...[
                    _buildInputField(
                      controller: _firstNameController,
                      label: 'Nombre/s',
                      icon: Icons.person_outline,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Ingresa tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      controller: _lastNameController,
                      label: 'Apellido/s',
                      icon: Icons.badge_outlined,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Ingresa tu apellido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<int>(
                            value: _selectedYearLevel,
                            label: 'Año',
                            icon: Icons.looks_one_rounded,
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1ro')),
                              DropdownMenuItem(value: 2, child: Text('2do')),
                              DropdownMenuItem(value: 3, child: Text('3ro')),
                            ],
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedYearLevel = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown<String>(
                            value: _selectedDivision,
                            label: 'División',
                            icon: Icons.class_outlined,
                            items: const [
                              DropdownMenuItem(
                                value: '1ra',
                                child: Text('1ra'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedDivision = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown<String>(
                      value: _selectedCareerName ?? 'Desarrollo de Software',
                      label: 'Carrera',
                      icon: Icons.account_balance_rounded,
                      items: careerItems,
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedCareerName = val);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildInputField(
                    controller: _emailController,
                    label: 'Correo electrónico',
                    icon: Icons.email_outlined,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresa tu correo';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    label: 'Contraseña',
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return 'La contraseña debe tener al menos 6 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: supabaseService.isLoading ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: supabaseService.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isRegisterMode ? 'Registrarme' : 'Iniciar Sesión',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isRegisterMode = !_isRegisterMode;
                        supabaseService.errorMessage = '';
                      });
                    },
                    child: Text(
                      _isRegisterMode
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
