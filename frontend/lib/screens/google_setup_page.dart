import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class GoogleSetupPage extends StatefulWidget {
  final String email;

  const GoogleSetupPage({super.key, required this.email});

  @override
  State<GoogleSetupPage> createState() => _GoogleSetupPageState();
}

class _GoogleSetupPageState extends State<GoogleSetupPage> {
  final _formKey = GlobalKey<FormState>();

  final heightController = TextEditingController();
  final weightController = TextEditingController();
  String selectedGender = "Male";

  bool isLoading = false;
  String resultMessage = "";

  Future<void> submitSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final height = double.parse(heightController.text.trim());
      final weight = double.parse(weightController.text.trim());

      // We'll call createProfile but with a dummy password since they use Google Auth
      // The backend will handle it securely.
      final result = await ApiService.createProfile(
        email: widget.email,
        password: "GOOGLE_AUTH_PLACEHOLDER_${DateTime.now().millisecondsSinceEpoch}",
        height: height,
        weight: weight,
        gender: selectedGender,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      setState(() => resultMessage = e.toString());
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
      appBar: AppBar(
        title: Text("Complete Setup", style: TextStyle(color: AppTheme.textPrimary(isDark))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textPrimary(isDark)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome!",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "We need a few details to recommend your perfect size before you start shopping.",
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary(isDark)),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.glassCard(isDark),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.glassBorder(isDark)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: heightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppTheme.textPrimary(isDark)),
                        decoration: InputDecoration(
                          labelText: "Height (cm)",
                          labelStyle: TextStyle(color: AppTheme.iconMuted(isDark)),
                          prefixIcon: Icon(Icons.height, color: AppTheme.iconMuted(isDark)),
                          filled: true,
                          fillColor: AppTheme.glassInput(isDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: AppTheme.textPrimary(isDark)),
                        decoration: InputDecoration(
                          labelText: "Weight (kg)",
                          labelStyle: TextStyle(color: AppTheme.iconMuted(isDark)),
                          prefixIcon: Icon(Icons.fitness_center, color: AppTheme.iconMuted(isDark)),
                          filled: true,
                          fillColor: AppTheme.glassInput(isDark),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: "Male", label: Text("Male"), icon: Icon(Icons.male)),
                            ButtonSegment(value: "Female", label: Text("Female"), icon: Icon(Icons.female)),
                          ],
                          selected: {selectedGender},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() {
                              selectedGender = newSelection.first;
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            backgroundColor: AppTheme.glassInput(isDark),
                            selectedForegroundColor: Colors.white,
                            selectedBackgroundColor: AppTheme.accentBlue(isDark),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
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
                          ),
                          onPressed: isLoading ? null : submitSetup,
                          child: isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text("Complete Profile", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (resultMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(resultMessage, style: TextStyle(color: AppTheme.accentRed(isDark))),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
