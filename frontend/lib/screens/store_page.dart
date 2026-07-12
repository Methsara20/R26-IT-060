import 'package:flutter/material.dart';
import 'create_zone_page.dart';
import 'identify_zone_page.dart';
import 'view_zones_page.dart';
import 'customer_tracking_page.dart';

class StorePage extends StatelessWidget {
  const StorePage({super.key});

  Widget _menuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, size: 36, color: Colors.blue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text("Store Dashboard"), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _menuButton(
              context: context,
              icon: Icons.add_location_alt,
              title: "Create Zone",
              subtitle: "Create a zone using 4 location points",
              page: const CreateZonePage(),
            ),
            _menuButton(
              context: context,
              icon: Icons.my_location,
              title: "Identify Zone",
              subtitle: "Check which zone a location belongs to",
              page: const IdentifyZonePage(),
            ),
            _menuButton(
              context: context,
              icon: Icons.map,
              title: "View Zones",
              subtitle: "View and delete stored zones",
              page: const ViewZonesPage(),
            ),
            _menuButton(
              context: context,
              icon: Icons.track_changes,
              title: "Customer Tracking & Alerts",
              subtitle: "Track live customers and view assistance requests",
              page: const CustomerTrackingPage(),
            ),
          ],
        ),
      ),
    );
  }
}
