import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'dart:ui';

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();

  String? selectedGender;
  String heightUnit = "cm";
  String weightUnit = "kg";

  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  String message = "";

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> genderOptions = [
    "male",
    "female",
    "prefer not to say",
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  double _heightToCm() {
    final height = _toDouble(heightController.text);
    return heightUnit == "inch" ? height * 2.54 : height;
  }

  double _weightToKg() {
    final weight = _toDouble(weightController.text);
    return weightUnit == "lb" ? weight * 0.453592 : weight;
  }

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "Email is required";
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    if (!emailRegex.hasMatch(value.trim())) return "Enter a valid email";
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) return "Password is required";
    if (value.trim().length < 8) return "Password must be at least 8 characters";
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value != passwordController.text) return "Passwords do not match";
    return null;
  }

  String? validateNumber(String? value, String label) {
    if (value == null || value.trim().isEmpty) return "$label is required";
    if (double.tryParse(value.trim()) == null) return "Enter a valid $label";
    return null;
  }

  Future<void> createProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedGender == null) {
      setState(() => message = "Please select gender");
      return;
    }

    setState(() => isLoading = true);

    try {
      final result = await ApiService.createProfile(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        height: _heightToCm(),
        weight: _weightToKg(),
        gender: selectedGender!,
      );

      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }

    if (mounted) setState(() => isLoading = false);
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: AppTheme.textPrimary(isDark), fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AppTheme.textSecondary(isDark)),
          prefixIcon: Icon(icon, color: AppTheme.iconMuted(isDark), size: 20),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppTheme.glassInput(isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.glassBorder(isDark)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.glassBorder(isDark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppTheme.accentBlue(isDark), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownUnit({
    required String value,
    required List<String> items,
    required Function(String) onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.glassInput(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder(isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.iconMuted(isDark)),
          dropdownColor: AppTheme.backgroundColor(isDark),
          style: TextStyle(color: AppTheme.textPrimary(isDark), fontWeight: FontWeight.w600, fontSize: 15),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final isDark = AppState().isDarkMode;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor(isDark),
          appBar: AppBar(
            title: Text("Create Profile", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark), fontSize: 18)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: AppTheme.textPrimary(isDark)),
          ),
          body: Stack(
            children: [
              // Background Glow Effects
              Positioned(
                top: -100,
                left: -100,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.orbPrimary(isDark).withOpacity(0.15),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -50,
                right: -100,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.orbSecondary(isDark).withOpacity(0.15),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("Let's get started", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text("Create a profile to unlock AI size matching.", style: TextStyle(fontSize: 15, color: AppTheme.textSecondary(isDark))),
                        const SizedBox(height: 40),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.glassCard(isDark),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.glassBorder(isDark)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Account Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary(isDark), letterSpacing: 1)),
                              const SizedBox(height: 20),
                              _buildInput(
                                label: "Email",
                                controller: emailController,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: validateEmail,
                                isDark: isDark,
                              ),
                              _buildInput(
                                label: "Password",
                                controller: passwordController,
                                icon: Icons.lock_outline,
                                obscure: !showPassword,
                                validator: validatePassword,
                                isDark: isDark,
                                suffixIcon: IconButton(
                                  icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off, color: AppTheme.iconMuted(isDark), size: 20),
                                  onPressed: () => setState(() => showPassword = !showPassword),
                                ),
                              ),
                              _buildInput(
                                label: "Confirm Password",
                                controller: confirmPasswordController,
                                icon: Icons.lock_outline,
                                obscure: !showConfirmPassword,
                                validator: validateConfirmPassword,
                                isDark: isDark,
                                suffixIcon: IconButton(
                                  icon: Icon(showConfirmPassword ? Icons.visibility : Icons.visibility_off, color: AppTheme.iconMuted(isDark), size: 20),
                                  onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                                ),
                              ),

                              const SizedBox(height: 12),
                              Divider(color: AppTheme.glassBorder(isDark)),
                              const SizedBox(height: 28),
                              
                              Text("Body Metrics (For AI)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary(isDark), letterSpacing: 1)),
                              const SizedBox(height: 20),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildInput(
                                      label: "Height",
                                      controller: heightController,
                                      icon: Icons.height,
                                      keyboardType: TextInputType.number,
                                      validator: (value) => validateNumber(value, "height"),
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: SizedBox(
                                      height: 58,
                                      child: _buildDropdownUnit(
                                        value: heightUnit,
                                        items: const ["cm", "inch"],
                                        onChanged: (value) => setState(() => heightUnit = value),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildInput(
                                      label: "Weight",
                                      controller: weightController,
                                      icon: Icons.monitor_weight_outlined,
                                      keyboardType: TextInputType.number,
                                      validator: (value) => validateNumber(value, "weight"),
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: SizedBox(
                                      height: 58,
                                      child: _buildDropdownUnit(
                                        value: weightUnit,
                                        items: const ["kg", "lb"],
                                        onChanged: (value) => setState(() => weightUnit = value),
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.glassInput(isDark),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.glassBorder(isDark)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedGender,
                                    icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.iconMuted(isDark)),
                                    dropdownColor: AppTheme.backgroundColor(isDark),
                                    style: TextStyle(color: AppTheme.textPrimary(isDark), fontSize: 15),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.iconMuted(isDark), size: 20),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                                    ),
                                    hint: Text("Select Gender", style: TextStyle(color: AppTheme.textSecondary(isDark))),
                                    items: genderOptions.map((gender) {
                                      return DropdownMenuItem(value: gender, child: Text(gender.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)));
                                    }).toList(),
                                    onChanged: (value) => setState(() => selectedGender = value),
                                    validator: (value) => value == null ? "Please select gender" : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentBlue(isDark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            onPressed: isLoading ? null : createProfile,
                            child: isLoading
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Create Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),

                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentRed(isDark).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppTheme.accentRed(isDark).withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: AppTheme.accentRed(isDark), size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(message, style: TextStyle(color: AppTheme.accentRed(isDark), fontSize: 13))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
        );
      }
    );
  }
}