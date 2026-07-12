import 'dart:async';
import 'package:flutter/material.dart';
import '../services/monitoring_api_service.dart';

class CustomerTrackingPage extends StatefulWidget {
  const CustomerTrackingPage({super.key});

  @override
  State<CustomerTrackingPage> createState() => _CustomerTrackingPageState();
}

class _CustomerTrackingPageState extends State<CustomerTrackingPage> {
  Timer? _refreshTimer;
  List<dynamic> _activeSessions = [];
  List<dynamic> _pendingRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrackingData();
    // Refresh tracking dashboard every 3 seconds for a real-time feel
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchTrackingData(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTrackingData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final sessions = await MonitoringApiService.getActiveSessions();
      final requests = await MonitoringApiService.getActiveRequests();
      setState(() {
        _activeSessions = sessions;
        _pendingRequests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (!silent) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching tracking data: $e")),
        );
      }
    }
  }

  Future<void> _resolveAlert(String requestId) async {
    try {
      await MonitoringApiService.resolveRequest(requestId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Assistance request marked as Resolved")),
      );
      _fetchTrackingData();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to resolve: $e")));
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return "Unknown";
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text("Customer Tracking & Alerts"),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.track_changes), text: "Live Tracking"),
              Tab(
                icon: Icon(Icons.warning_amber_rounded),
                text: "Assistance Alerts",
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildLiveTrackingTab(),
                  _buildAssistanceAlertsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildLiveTrackingTab() {
    if (_activeSessions.isEmpty) {
      return const Center(
        child: Text(
          "No customers currently active in Virtual Try-On",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeSessions.length,
      itemBuilder: (context, index) {
        final session = _activeSessions[index];
        final name = session["customer_name"] ?? "Guest";
        final email = session["customer_id"] ?? "";
        final zone = session["zone_name"] ?? "Unknown Zone";
        final lat = session["latitude"] ?? 0.0;
        final lon = session["longitude"] ?? 0.0;
        final alt = session["altitude"] ?? 0.0;
        final entry = _formatTime(session["entry_time"]);
        final lastUpd = _formatTime(session["last_updated"]);

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFEAF1FF),
                          child: Icon(Icons.person, color: Color(0xFF2563EB)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Active",
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.blueAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Current Zone: ",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      zone,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.gps_fixed, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "GPS: Lat ${lat.toStringAsFixed(6)}, Lon ${lon.toStringAsFixed(6)} (Alt: ${alt.toStringAsFixed(1)}m)",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Entered Zone: $entry",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      "Last Updated: $lastUpd",
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAssistanceAlertsTab() {
    if (_pendingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text(
              "No pending assistance requests",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final req = _pendingRequests[index];
        final id = req["request_id"];
        final name = req["customer_name"] ?? "Customer";
        final email = req["customer_id"] ?? "";
        final zone = req["zone_name"] ?? "Unknown Zone";
        final count = req["notification_count"] ?? 1;
        final time = _formatTime(req["request_time"]);

        return Card(
          color: const Color(0xFFFFF2F2), // Light red warning bg
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.red.shade200, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red.shade100,
                          child: const Icon(Icons.warning, color: Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "Alert x$count",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.redAccent),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Needs Assistance In: ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    Text(
                      zone,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "First Triggered At: $time",
                  style: const TextStyle(color: Colors.black, fontSize: 13),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _resolveAlert(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text("Mark as Resolved"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
