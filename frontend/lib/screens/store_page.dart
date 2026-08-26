import 'package:flutter/material.dart';
import '../services/monitoring_api_service.dart';
import '../widgets/zone_bar_chart.dart';
import 'create_zone_page.dart';
import 'identify_zone_page.dart';
import 'view_zones_page.dart';
import 'customer_tracking_page.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  bool _isLoadingAnalytics = true;
  List<dynamic> _zonesAnalytics = [];
  String _topHotZone = "None";
  String _topDeadZone = "None";

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => _isLoadingAnalytics = true);
    try {
      final data = await MonitoringApiService.getZoneAnalytics();
      if (mounted) {
        setState(() {
          _zonesAnalytics = data["zones"] ?? [];
          _topHotZone = data["top_hot_zone"] ?? "None";
          _topDeadZone = data["top_dead_zone"] ?? "None";
          _isLoadingAnalytics = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingAnalytics = false);
      }
    }
  }

  Widget _menuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => page));
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, size: 28, color: const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Store Manager Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAnalytics,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Metric Summary Cards
              Row(
                children: [
                  _buildStatCard(
                    "Top Hot Zone",
                    _topHotZone,
                    Icons.local_fire_department_rounded,
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 12),
                  _buildStatCard(
                    "Top Dead Zone",
                    _topDeadZone,
                    Icons.ac_unit_rounded,
                    const Color(0xFFF59E0B),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Bar Chart Analytics Section
              _isLoadingAnalytics
                  ? Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : ZoneBarChartWidget(
                      zones: _zonesAnalytics,
                      topHotZone: _topHotZone,
                      topDeadZone: _topDeadZone,
                      onRefresh: _fetchAnalytics,
                    ),

              const SizedBox(height: 28),

              const Text(
                "Management Tools",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Manage store layouts and track live customer trajectories.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              _menuButton(
                context: context,
                icon: Icons.add_location_alt_rounded,
                title: "Create Zone",
                subtitle: "Define new store sections with GPS",
                page: const CreateZonePage(),
              ),
              _menuButton(
                context: context,
                icon: Icons.my_location_rounded,
                title: "Identify Zone",
                subtitle: "Check what zone a location falls into",
                page: const IdentifyZonePage(),
              ),
              _menuButton(
                context: context,
                icon: Icons.map_rounded,
                title: "View Zones",
                subtitle: "Manage and delete existing layout zones",
                page: const ViewZonesPage(),
              ),
              const SizedBox(height: 12),
              const Text(
                "Analytics & Live Alerts",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 16),
              _menuButton(
                context: context,
                icon: Icons.track_changes_rounded,
                title: "Customer Tracking",
                subtitle: "Live maps & assistance requests",
                page: const CustomerTrackingPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
