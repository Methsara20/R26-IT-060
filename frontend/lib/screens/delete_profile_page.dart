import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'dart:ui';

class DeleteProfilePage extends StatefulWidget {
  final String profileId;
  final VoidCallback onDeleted;

  const DeleteProfilePage({
    super.key,
    required this.profileId,
    required this.onDeleted,
  });

  @override
  State<DeleteProfilePage> createState() => _DeleteProfilePageState();
}

class _DeleteProfilePageState extends State<DeleteProfilePage> with SingleTickerProviderStateMixin {
  bool isLoading = false;
  String message = "";
  
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));
    _animController.forward();
  }
  
  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> deleteProfile() async {
    setState(() => isLoading = true);

    try {
      await ApiService.deleteProfile(widget.profileId);
      widget.onDeleted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }

    if (mounted) setState(() => isLoading = false);
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
            title: Text("Delete Profile", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark), fontSize: 18)),
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
                      color: AppTheme.accentRed(isDark).withOpacity(0.15),
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
                child: Padding(
                padding: const EdgeInsets.all(28),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppTheme.glassCard(isDark),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: AppTheme.glassBorder(isDark)),
                          boxShadow: [
                            BoxShadow(color: AppTheme.accentRed(isDark).withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 20)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed(isDark).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.warning_rounded, size: 64, color: AppTheme.accentRed(isDark)),
                            ),
                            const SizedBox(height: 32),
                            Text("Delete Profile?", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), letterSpacing: -0.5)),
                            const SizedBox(height: 12),
                            Text(
                              "This action cannot be undone. All your AI measurements, past orders, and favorites will be permanently lost.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary(isDark), height: 1.5),
                            ),
                            const SizedBox(height: 40),

                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: isLoading ? null : deleteProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentRed(isDark),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: isLoading
                                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Text("Yes, Delete Everything", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: TextButton(
                                onPressed: isLoading ? null : () => Navigator.pop(context),
                                style: TextButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text("Cancel & Keep Profile", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary(isDark))),
                              ),
                            ),

                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRed(isDark).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
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
              ),
              ),
            ],
          ),
        );
      }
    );
  }
}