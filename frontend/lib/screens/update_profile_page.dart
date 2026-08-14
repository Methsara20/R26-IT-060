import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'dart:ui';

class UpdateProfilePage extends StatefulWidget {
  final String profileId;

  const UpdateProfilePage({
    super.key,
    required this.profileId,
  });

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> with SingleTickerProviderStateMixin {
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final passwordController = TextEditingController();

  String heightUnit = "cm";
  String weightUnit = "kg";
  String? selectedGender;

  bool isLoading = false;
  bool showPassword = false;
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
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    heightController.dispose();
    weightController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  double _toDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  double? _heightToCm() {
    if (heightController.text.trim().isEmpty) return null;
    final height = _toDouble(heightController.text);
    return heightUnit == "inch" ? height * 2.54 : height;
  }

  double? _weightToKg() {
    if (weightController.text.trim().isEmpty) return null;
    final weight = _toDouble(weightController.text);
    return weightUnit == "lb" ? weight * 0.453592 : weight;
  }

  Future<void> updateProfile() async {
    setState(() => isLoading = true);

    try {
      final response = await ApiService.updateProfile(
        profileId: widget.profileId,
        height: _heightToCm(),
        weight: _weightToKg(),
        gender: selectedGender,
        password: passwordController.text.trim().isEmpty ? null : passwordController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text("Profile measurements updated!", style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, response);
      }
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
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
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
            title: Text("Update Profile", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark), fontSize: 18)),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text("Body Metrics", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), letterSpacing: -0.5)),
                        const SizedBox(height: 8),
                        Text("Update your physical measurements so our AI can recalculate your bespoke sizes.", style: TextStyle(fontSize: 15, color: AppTheme.textSecondary(isDark), height: 1.5)),
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
                            Text("Physical Attributes", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary(isDark), letterSpacing: 1)),
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
                                  hint: Text("Select Gender (Optional)", style: TextStyle(color: AppTheme.textSecondary(isDark))),
                                  items: genderOptions.map((gender) {
                                    return DropdownMenuItem(value: gender, child: Text(gender.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)));
                                  }).toList(),
                                  onChanged: (value) => setState(() => selectedGender = value),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),
                            Divider(color: AppTheme.glassBorder(isDark)),
                            const SizedBox(height: 28),

                            Text("Security", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textSecondary(isDark), letterSpacing: 1)),
                            const SizedBox(height: 20),
                            _buildInput(
                              label: "New Password (Optional)",
                              controller: passwordController,
                              icon: Icons.lock_outline,
                              obscure: !showPassword,
                              isDark: isDark,
                              suffixIcon: IconButton(
                                icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off, color: AppTheme.iconMuted(isDark), size: 20),
                                onPressed: () => setState(() => showPassword = !showPassword),
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
                          onPressed: isLoading ? null : updateProfile,
                          child: isLoading
                              ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text("Save Changes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
            ],
          ),
        );
      }
    );
  }
}