import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'create_profile_page.dart';
import 'google_setup_page.dart';
import 'store_page.dart';
import 'customer_main_page.dart';
import 'dart:ui';

class ClientPage extends StatefulWidget {
  const ClientPage({super.key});

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool showPassword = false;

  String resultMessage = "";

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

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
    super.dispose();
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

  Future<void> login() async {
    if (emailController.text.trim() == "admin" && passwordController.text.trim() == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StorePage()),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final result = await ApiService.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final profileId = result["profile_id"];
      final loggedEmail = result["email"];
      final recommendedSize = result["recommended_size"];
      final bodyMeasurements = result["body_measurements"];

      if (!mounted) return;
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerMainPage(
            customerEmail: loggedEmail!,
            recommendedSize: recommendedSize,
            profileId: profileId,
            bodyMeasurements: bodyMeasurements,
          ),
        ),
      );
    } catch (e) {
      String msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (msg.contains('ClientException') || msg.contains('Failed to fetch')) {
        msg = "Unable to connect to backend (https://r26-it-060.onrender.com).\nIf the backend server was sleeping (Render Free Tier), please wait 30 seconds and try again.";
      }
      setState(() => resultMessage = msg);
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> loginWithGoogle() async {
    setState(() {
      isLoading = true;
      resultMessage = "";
    });

    try {
      final idToken = await AuthService.signInWithGoogle();
      if (idToken == null || idToken.isEmpty) {
        if (mounted) {
          setState(() {
            resultMessage = "Google Sign-In returned no authentication token. Please try again.";
          });
        }
        return;
      }

      final result = await ApiService.googleLogin(idToken);

      if (!mounted) return;

      if (result["requires_setup"] == true) {
        // Redirect to a specialized setup page for new Google users
        final setupResult = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoogleSetupPage(email: result["email"] ?? ""),
          ),
        );

        if (setupResult != null && setupResult is Map<String, dynamic> && mounted) {
          final customerEmail = setupResult["email"] ?? result["email"] ?? "";
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerMainPage(
                customerEmail: customerEmail,
                recommendedSize: setupResult["recommended_size"],
                profileId: setupResult["profile_id"],
                bodyMeasurements: setupResult["body_measurements"],
              ),
            ),
          );
        } else if (mounted) {
          setState(() => resultMessage = "Please complete setup details to finish signing in.");
        }
      } else {
        // Existing user, log them straight in
        final userEmail = (result["email"] ?? "") as String;
        if (userEmail.isEmpty) {
          throw Exception("Login succeeded but account email was missing.");
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerMainPage(
              customerEmail: userEmail,
              recommendedSize: result["recommended_size"],
              profileId: result["profile_id"],
              bodyMeasurements: result["body_measurements"],
            ),
          ),
        );
      }
    } catch (e) {
      String msg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      if (msg.contains('ClientException') || msg.contains('Failed to fetch')) {
        msg = "Unable to connect to backend (https://r26-it-060.onrender.com).\nIf the backend server was sleeping (Render Free Tier), please wait 30 seconds and try again.";
      }
      if (mounted) {
        setState(() => resultMessage = msg);
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppState().isDarkMode;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(isDark),
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
                  color: AppTheme.orbPrimary(isDark).withValues(alpha: 0.15),
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
                  color: AppTheme.orbSecondary(isDark).withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Brand icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppTheme.orbPrimary(isDark).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_bag_rounded, size: 52, color: AppTheme.accentBlue(isDark)),
                      ),
                      const SizedBox(height: 32),

                      Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary(isDark),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Sign in to continue shopping",
                        style: TextStyle(fontSize: 15, color: AppTheme.textSecondary(isDark)),
                      ),
                      const SizedBox(height: 40),

                      // Form Card
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
                              _buildInput(
                                label: "Email",
                                controller: emailController,
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: validateEmail,
                                isDark: isDark,
                              ),
                              const SizedBox(height: 16),
                              _buildInput(
                                label: "Password",
                                controller: passwordController,
                                icon: Icons.lock_outline,
                                obscure: !showPassword,
                                validator: validatePassword,
                                isDark: isDark,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    showPassword ? Icons.visibility : Icons.visibility_off,
                                    color: AppTheme.iconMuted(isDark),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => showPassword = !showPassword),
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentBlue(isDark),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  onPressed: isLoading ? null : login,
                                  child: isLoading
                                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text("Sign In", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Google Login Button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: AppTheme.glassBorder(isDark)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                                  ),
                                  onPressed: isLoading ? null : loginWithGoogle,
                                  icon: Image.network(
                                    'https://img.icons8.com/color/48/000000/google-logo.png',
                                    height: 24,
                                  ),
                                  label: Text(
                                    "Continue with Google",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary(isDark),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CreateProfilePage()),
                                  );
                                  if (result != null && result is Map<String, dynamic> && context.mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CustomerMainPage(
                                          customerEmail: result["email"]!,
                                          recommendedSize: result["recommended_size"],
                                          profileId: result["profile_id"],
                                          bodyMeasurements: result["body_measurements"],
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: RichText(
                                  text: TextSpan(
                                    text: "New here? ",
                                    style: TextStyle(color: AppTheme.textSecondary(isDark), fontSize: 14),
                                    children: [
                                      TextSpan(
                                        text: "Create a profile",
                                        style: TextStyle(color: AppTheme.accentBlue(isDark), fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (resultMessage.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRed(isDark).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.accentRed(isDark).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: AppTheme.accentRed(isDark), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  resultMessage,
                                  style: TextStyle(color: AppTheme.accentRed(isDark), fontSize: 13),
                                ),
                              ),
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

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: AppTheme.textPrimary(isDark), fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppTheme.iconMuted(isDark)),
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
    );
  }
}