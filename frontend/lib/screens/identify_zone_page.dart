import 'package:flutter/material.dart';
import '../services/zone_api_service.dart';
import '../services/location_service.dart';

class IdentifyZonePage extends StatefulWidget {
  const IdentifyZonePage({super.key});

  @override
  State<IdentifyZonePage> createState() => _IdentifyZonePageState();
}

class _IdentifyZonePageState extends State<IdentifyZonePage> {
  String result = "Press the button to identify your current zone";
  Map<String, dynamic>? currentPoint;
  bool isLoading = false;
  bool isSuccess = false;

  Future<void> identifyCurrentZone() async {
    setState(() {
      isLoading = true;
      result = "Getting current location...";
      currentPoint = null;
      isSuccess = false;
    });

    try {
      final point = await LocationService.getCurrentPoint();

      if (!mounted) return;

      setState(() {
        currentPoint = point;
        result = "Sending location to backend...";
      });

      final response = await ZoneApiService.identifyZone(
        latitude: point["latitude"],
        longitude: point["longitude"],
        altitude: point["altitude"],
      );

      if (!mounted) return;

      if (response["zones"] != null && response["zones"].isNotEmpty) {
        final zones = response["zones"] as List;
        final zoneNames = zones.map((z) => z["zone_name"]).join(", ");

        setState(() {
          result = "Matched Zone: $zoneNames";
          isSuccess = true;
        });
      } else if (response["zone_name"] != null) {
        setState(() {
          result = "Matched Zone: ${response["zone_name"]}";
          isSuccess = true;
        });
      } else {
        setState(() {
          result = response["message"].toString();
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        result = "Error: $e";
      });
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Widget _locationCard() {
    return Container(
      width: double.infinity,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: currentPoint == null
            ? Column(
                children: [
                  Icon(Icons.location_disabled, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text(
                    "Current location not captured yet",
                    style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.my_location, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(width: 12),
                      const Text("Current GPS Fix", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Lat: ${currentPoint!["latitude"]}", style: const TextStyle(fontFamily: 'monospace')),
                        const SizedBox(height: 6),
                        Text("Lon: ${currentPoint!["longitude"]}", style: const TextStyle(fontFamily: 'monospace')),
                        const SizedBox(height: 6),
                        Text("Alt: ${currentPoint!["altitude"]}", style: const TextStyle(fontFamily: 'monospace')),
                      ],
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
          "Identify Zone",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.radar, size: 64, color: Color(0xFF94A3B8)),
            const SizedBox(height: 16),
            const Text(
              "Where am I?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Check which zone your current physical location falls into.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 32),
            _locationCard(),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: isLoading ? null : identifyCurrentZone,
                icon: isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.search, color: Colors.white),
                label: isLoading
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "Identify My Current Zone",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFFDCFCE7) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSuccess ? const Color(0xFF86EFAC) : Colors.grey.shade200,
                ),
              ),
              child: Column(
                children: [
                  if (isSuccess) const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 32),
                  if (isSuccess) const SizedBox(height: 12),
                  Text(
                    result,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? const Color(0xFF14532D) : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}