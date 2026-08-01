import 'package:flutter/material.dart';
import '../services/zone_api_service.dart';

class ViewZonesPage extends StatefulWidget {
  const ViewZonesPage({super.key});

  @override
  State<ViewZonesPage> createState() => _ViewZonesPageState();
}

class _ViewZonesPageState extends State<ViewZonesPage> {
  List zones = [];
  bool isLoading = true;

  Future<void> loadZones() async {
    setState(() => isLoading = true);

    try {
      final response = await ZoneApiService.getAllZones();
      setState(() {
        zones = response["zones"] ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() => isLoading = false);
  }

  Future<void> deleteZone(String zoneId) async {
    try {
      final response = await ZoneApiService.deleteZone(zoneId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response["message"].toString()),
          behavior: SnackBarBehavior.floating,
        ),
      );

      loadZones();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Delete failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    loadZones();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          "Manage Zones",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            onPressed: loadZones,
            icon: const Icon(Icons.refresh, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
          : zones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      const Text(
                        "No zones found",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Create a zone first from the dashboard.",
                        style: TextStyle(color: Colors.black45),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: zones.length,
                  itemBuilder: (context, index) {
                    final zone = zones[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEFF6FF),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.location_on, color: Color(0xFF2563EB)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      zone["zone_name"] ?? "Unnamed Zone",
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1E293B)),
                                    ),
                                  ],
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () {
                                    deleteZone(zone["zone_id"]);
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Bounding Box", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Lat: ${zone["min_lat"]} - ${zone["max_lat"]}",
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Lon: ${zone["min_lon"]} - ${zone["max_lon"]}",
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Alt: ${zone["min_alt"]} - ${zone["max_alt"]}",
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}