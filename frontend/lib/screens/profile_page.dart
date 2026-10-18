import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'update_profile_page.dart';
import 'delete_profile_page.dart';
import 'client_page.dart';

class ProfilePage extends StatelessWidget {
  final String customerEmail;
  final String? recommendedSize;
  final String? profileId;
  final Map<String, dynamic>? bodyMeasurements;
  final void Function(String? recommendedSize, Map<String, dynamic>? bodyMeasurements)? onProfileUpdated;

  const ProfilePage({
    super.key,
    required this.customerEmail,
    this.recommendedSize,
    this.profileId,
    this.bodyMeasurements,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = customerEmail.split('@')[0];
    final capitalizedName = firstName.isNotEmpty
        ? firstName[0].toUpperCase() + firstName.substring(1)
        : "User";

    return ListenableBuilder(
      listenable: AppState(),
      builder: (context, _) {
        final isDark = AppState().isDarkMode;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor(isDark),
          body: Stack(
            children: [
              // Background Glow Effects
              Positioned(
                top: -50,
                left: -50,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.orbPrimary(isDark).withValues(alpha: 0.2),
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

              CustomScrollView(
                slivers: [
                  // Glass Header
                  SliverToBoxAdapter(
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
                          decoration: BoxDecoration(
                            color: AppTheme.glassBackground(isDark),
                            border: Border(bottom: BorderSide(color: AppTheme.glassBorder(isDark))),
                          ),
                          child: Column(
                            children: [
                              // Avatar
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [AppTheme.accentBlue(isDark), AppTheme.orbSecondary(isDark)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(color: AppTheme.accentBlue(isDark).withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 10)),
                                  ],
                                  border: Border.all(color: AppTheme.glassBorder(isDark), width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    capitalizedName[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                capitalizedName,
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                customerEmail,
                                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary(isDark)),
                              ),

                              if (recommendedSize != null) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentBlue(isDark).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: AppTheme.accentBlue(isDark).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: AppTheme.accentBlue(isDark), size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Base Size: $recommendedSize',
                                        style: TextStyle(color: AppTheme.accentBlue(isDark), fontWeight: FontWeight.w800, fontSize: 13),
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

                  // Theme Toggle
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.glassCard(isDark),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.glassBorder(isDark)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.accentBlue(isDark).withValues(alpha: 0.15) : AppTheme.orbSecondary(isDark).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: isDark ? AppTheme.accentBlue(isDark) : AppTheme.orbSecondary(isDark), size: 20),
                          ),
                          title: Text("Dark Mode", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary(isDark))),
                          trailing: Switch(
                            value: isDark,
                            onChanged: (val) {
                              AppState().toggleTheme();
                            },
                            activeThumbColor: AppTheme.accentBlue(isDark),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Body Measurements
                  if (bodyMeasurements != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.glassCard(isDark),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppTheme.glassBorder(isDark)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentBlue(isDark).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(Icons.auto_awesome, color: AppTheme.accentBlue(isDark), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Text("AI Body Model", style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textPrimary(isDark), fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _measurementBar("Shoulder Width", "${bodyMeasurements!['predicted_shoulder_width']} in", 0.7, AppTheme.accentBlue(isDark), isDark),
                              _measurementBar("Waist", "${bodyMeasurements!['predicted_waist']} in", 0.6, AppTheme.orbSecondary(isDark), isDark),
                              _measurementBar("Leg Length", "${bodyMeasurements!['predicted_leg_length']} in", 0.8, AppTheme.accentGreen(isDark), isDark),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Menu Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 12),
                            child: Text("ACCOUNT", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textSecondary(isDark), letterSpacing: 2)),
                          ),
                          _menuCard(
                            context,
                            title: "Update Body Profile",
                            icon: Icons.straighten,
                            color: AppTheme.accentBlue(isDark),
                            isDark: isDark,
                            onTap: () async {
                              if (profileId != null) {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => UpdateProfilePage(profileId: profileId!)),
                                );
                                if (result != null && result is Map && onProfileUpdated != null) {
                                   onProfileUpdated!(result["recommended_size"], result["body_measurements"]);
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("No body profile found to update.", style: TextStyle(color: AppTheme.textPrimary(isDark)))),
                                );
                              }
                            },
                          ),
                          _menuCard(
                            context,
                            title: "Delete Body Profile",
                            icon: Icons.delete_outline,
                            color: AppTheme.accentRed(isDark),
                            isDark: isDark,
                            onTap: () {
                              if (profileId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeleteProfilePage(
                                      profileId: profileId!,
                                      onDeleted: () {
                                        AppState().clearCart();
                                        Navigator.pushAndRemoveUntil(
                                          context,
                                          MaterialPageRoute(builder: (_) => const ClientPage()),
                                          (route) => false,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Recent Orders
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 12),
                            child: Text("ORDERS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.textSecondary(isDark), letterSpacing: 2)),
                          ),
                          _buildOrderHistory(isDark),
                        ],
                      ),
                    ),
                  ),

                  // Logout
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppTheme.accentRed(isDark), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            AppState().clearCart();
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const ClientPage()),
                              (route) => false,
                            );
                          },
                          icon: Icon(Icons.logout, color: AppTheme.accentRed(isDark)),
                          label: Text("Log Out", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.accentRed(isDark))),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _measurementBar(String label, String value, double ratio, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textSecondary(isDark), fontSize: 13)),
              Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppTheme.glassBackground(isDark),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap, required bool isDark}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.glassCard(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.glassBorder(isDark)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary(isDark))),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary(isDark)),
      ),
    );
  }

  Widget _buildOrderHistory(bool isDark) {
    final orders = AppState().orderHistory;
    if (orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.glassCard(isDark),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.glassBorder(isDark)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.glassBackground(isDark), shape: BoxShape.circle),
              child: Icon(Icons.receipt_long, size: 36, color: AppTheme.iconMuted(isDark)),
            ),
            const SizedBox(height: 20),
            Text("No recent orders", style: TextStyle(color: AppTheme.textSecondary(isDark), fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Column(
      children: orders.map((order) {
        final date = DateTime.parse(order['date']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.glassCard(isDark),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.glassBorder(isDark)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(order['order_id'], style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.textPrimary(isDark), fontSize: 16)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppTheme.accentGreen(isDark).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Text("Delivered", style: TextStyle(fontSize: 10, color: AppTheme.accentGreen(isDark), fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${date.day}/${date.month}/${date.year}', style: TextStyle(color: AppTheme.textSecondary(isDark), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Divider(height: 1, color: AppTheme.glassBorder(isDark)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${order['items'].length} Items", style: TextStyle(color: AppTheme.textSecondary(isDark), fontWeight: FontWeight.w600)),
                  Text("LKR ${order['total'].toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.accentBlue(isDark), fontSize: 18)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
