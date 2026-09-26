import 'package:flutter/material.dart';

class ZoneBarChartWidget extends StatefulWidget {
  final List<dynamic> zones;
  final String? topHotZone;
  final String? topDeadZone;
  final VoidCallback? onRefresh;

  const ZoneBarChartWidget({
    super.key,
    required this.zones,
    this.topHotZone,
    this.topDeadZone,
    this.onRefresh,
  });

  @override
  State<ZoneBarChartWidget> createState() => _ZoneBarChartWidgetState();
}

class _ZoneBarChartWidgetState extends State<ZoneBarChartWidget> {
  int? _selectedZoneIndex;

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'HOT':
        return const Color(0xFF10B981); // Emerald Green
      case 'DEAD':
        return const Color(0xFFF59E0B); // Amber / Orange
      default:
        return const Color(0xFF3B82F6); // Electric Blue
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'HOT':
        return Icons.local_fire_department_rounded;
      case 'DEAD':
        return Icons.ac_unit_rounded;
      default:
        return Icons.trending_up_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.zones.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.bar_chart_rounded, size: 44, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              "No Zone Dwell Data Yet",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            const Text(
              "Dwell statistics will appear automatically as active customer tracking session data accumulates.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ],
        ),
      );
    }

    // Determine max dwell minutes for relative scaling
    double maxDwell = 0.1;
    for (var z in widget.zones) {
      final double dwell = ((z["total_dwell_minutes"] ?? 0) as num).toDouble();
      if (dwell > maxDwell) maxDwell = dwell;
    }

    final selectedZone = (_selectedZoneIndex != null && _selectedZoneIndex! < widget.zones.length)
        ? widget.zones[_selectedZoneIndex!]
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.leaderboard_rounded, color: Color(0xFF2563EB), size: 20),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "Hot / Dead Zone Analysis",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Customer Dwell Time & Layout Performance",
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.onRefresh != null)
                IconButton(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: "Refresh Analytics",
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Status Badge Legend - Wrap prevents right overflow on any screen width
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildLegendChip("🔥 Hot Zone", const Color(0xFF10B981)),
              _buildLegendChip("⚡ Normal", const Color(0xFF3B82F6)),
              _buildLegendChip("❄️ Dead Zone", const Color(0xFFF59E0B)),
            ],
          ),

          const SizedBox(height: 20),

          // Bar Chart Visualization Canvas with Responsive Scroll
          LayoutBuilder(
            builder: (context, constraints) {
              final double availableWidth = constraints.maxWidth;
              final int count = widget.zones.length;
              // Minimum bar width is 50px for proper spacing; scroll horizontally if total width > available
              final double minBarWidth = 50.0;
              final double calculatedBarWidth = availableWidth / count;
              final double actualBarWidth = calculatedBarWidth < minBarWidth ? minBarWidth : calculatedBarWidth;
              final double totalContentWidth = count * actualBarWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: totalContentWidth > availableWidth
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                child: SizedBox(
                  width: totalContentWidth < availableWidth ? availableWidth : totalContentWidth,
                  height: 180,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(count, (index) {
                      final zone = widget.zones[index];
                      final String name = (zone["zone_name"] ?? "Zone").toString();
                      final double dwellMins = ((zone["total_dwell_minutes"] ?? 0) as num).toDouble();
                      final String status = (zone["status"] ?? "Normal").toString();
                      final Color barColor = _getStatusColor(status);
                      final bool isSelected = _selectedZoneIndex == index;

                      final double heightRatio = (dwellMins / maxDwell).clamp(0.15, 1.0);

                      return SizedBox(
                        width: actualBarWidth,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedZoneIndex = isSelected ? null : index;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Formatted Dwell Value Label
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    dwellMins >= 1000
                                        ? "${(dwellMins / 1000).toStringAsFixed(1)}k m"
                                        : "${dwellMins.toStringAsFixed(1)}m",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? barColor : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // Animated Bar Box
                                Flexible(
                                  child: FractionallySizedBox(
                                    heightFactor: heightRatio,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        color: isSelected ? barColor : barColor.withValues(alpha: 0.85),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                                        border: isSelected
                                            ? Border.all(color: Colors.black.withValues(alpha: 0.2), width: 2)
                                            : null,
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: barColor.withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                )
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 6),

                                // Zone Name Label
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    name.length > 7 ? "${name.substring(0, 6)}…" : name,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            },
          ),

          // Selected Zone Detail Tooltip Banner
          if (selectedZone != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(selectedZone["status"] ?? "").withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getStatusColor(selectedZone["status"] ?? "").withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(selectedZone["status"] ?? ""),
                    color: _getStatusColor(selectedZone["status"] ?? ""),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${selectedZone['zone_name']} (${selectedZone['status'].toString().toUpperCase()})",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: _getStatusColor(selectedZone["status"] ?? ""),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Total Dwell: ${selectedZone['total_dwell_minutes']} mins | Visitors: ${selectedZone['visitor_count'] ?? 0}",
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
