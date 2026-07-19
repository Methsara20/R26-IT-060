import 'package:flutter/material.dart';
import '../services/app_state.dart';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "My Profile",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2), width: 4),
                    ),
                    child: Center(
                      child: Text(
                        customerEmail.isNotEmpty ? customerEmail[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    customerEmail,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  if (recommendedSize != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Recommended Size: $recommendedSize',
                            style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (bodyMeasurements != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 16),
                              SizedBox(width: 8),
                              Text("AI Tailored Measurements", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildMeasurementRow("Shoulder Width", "${bodyMeasurements!['predicted_shoulder_width']} inches"),
                          _buildMeasurementRow("Waist", "${bodyMeasurements!['predicted_waist']} inches"),
                          _buildMeasurementRow("Leg Length", "${bodyMeasurements!['predicted_leg_length']} inches"),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // Settings
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      "Account Settings",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  _buildMenuCard(
                    context,
                    title: "Update Body Profile",
                    icon: Icons.straighten,
                    color: const Color(0xFF2563EB),
                    onTap: () async {
                      if (profileId != null) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UpdateProfilePage(
                              profileId: profileId!,
                            ),
                          ),
                        );
                        
                        if (result != null && result is Map && onProfileUpdated != null) {
                           onProfileUpdated!(
                             result["recommended_size"],
                             result["body_measurements"]
                           );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No body profile found to update.")),
                        );
                      }
                    },
                  ),
                  _buildMenuCard(
                    context,
                    title: "Delete Body Profile",
                    icon: Icons.delete_outline,
                    color: Colors.redAccent,
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
                  
                  const SizedBox(height: 24),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 8),
                    child: Text(
                      "Recent Orders",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                  _buildOrderHistory(),
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        // Logout by pushing client page and clearing state
                        AppState().clearCart();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const ClientPage()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        "Log Out",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ),
    );
  }

  Widget _buildOrderHistory() {
    final orders = AppState().orderHistory;
    if (orders.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_long, size: 48, color: Colors.black12),
            SizedBox(height: 12),
            Text("No recent orders", style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Column(
      children: orders.map((order) {
        final date = DateTime.parse(order['date']);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order['order_id'],
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text("Delivered", style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("${order['items'].length} Items", style: const TextStyle(color: Colors.black54)),
                  Text(
                    "LKR ${order['total'].toStringAsFixed(0)}",
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2563EB), fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMeasurementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
        ],
      ),
    );
  }
}
