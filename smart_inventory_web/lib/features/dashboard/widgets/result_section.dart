import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class ResultSection extends StatelessWidget {
  final Map<String, dynamic>? result;

  const ResultSection({super.key, this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null || result!.isEmpty) {
      return const SizedBox();
    }

    final forecastList =
        (result?["forecast_7_days_list"] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];

    final trend = result?["trend"] ?? "STABLE";

    final predicted = (result?["predicted_demand"] ?? 0).toDouble();

    final forecast7 = result?["forecast_7_days"]?.toString() ?? "-";

    final confidence = result?["confidence"]?.toString() ?? "MEDIUM";

    final explanation = result?["explanation"] ?? "No explanation available";

    
    // TREND STYLES
    

    Color trendColor;
    Color trendBg;
    IconData trendIcon;
    String trendLabel;

    if (trend == "UP") {
      trendColor = const Color(0xFF16A34A);

      trendBg = const Color(0xFFDCFCE7);

      trendIcon = Icons.trending_up_rounded;

      trendLabel = "Increasing";
    } else if (trend == "DOWN") {
      trendColor = const Color(0xFFDC2626);

      trendBg = const Color(0xFFFEE2E2);

      trendIcon = Icons.trending_down_rounded;

      trendLabel = "Decreasing";
    } else {
      trendColor = const Color(0xFF6B7280);

      trendBg = const Color(0xFFF3F4F6);

      trendIcon = Icons.trending_flat_rounded;

      trendLabel = "Stable";
    }

    
    //  CHART RANGE
    

    double minY = forecastList.isNotEmpty
        ? (forecastList.reduce((a, b) => a < b ? a : b) - 2).floorToDouble()
        : 0;

    double maxY = forecastList.isNotEmpty
        ? (forecastList.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble()
        : 30;

    if (minY < 0) minY = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        const SizedBox(height: 10),

        
        //  KPI SECTION
        
        Row(
          children: [
            Expanded(
              child: _kpiCard(
                title: "Daily Demand",

                value: predicted.toStringAsFixed(1),

                subtitle: "units",

                icon: Icons.analytics_outlined,

                color: const Color(0xFF2563EB),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: _kpiCard(
                title: "7-Day Forecast",

                value: forecast7,

                subtitle: "weekly total",

                icon: Icons.calendar_month_outlined,

                color: const Color(0xFF7C3AED),
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: _kpiCard(
                title: "Confidence",

                value: confidence,

                subtitle: "prediction reliability",

                icon: Icons.verified_outlined,

                color: const Color(0xFF16A34A),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        
        //  TREND BADGE
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

          decoration: BoxDecoration(
            color: trendBg,

            borderRadius: BorderRadius.circular(14),
          ),

          child: Row(
            mainAxisSize: MainAxisSize.min,

            children: [
              Icon(trendIcon, color: trendColor, size: 20),

              const SizedBox(width: 8),

              Text(
                "Demand Trend: $trendLabel",

                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: trendColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        
        //  FORECAST CHART CARD
        
        Container(
          width: double.infinity,

          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(20),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),

                blurRadius: 20,

                offset: const Offset(0, 8),
              ),
            ],
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const Text(
                        "7-Day Demand Forecast",

                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        "AI-generated weekly demand projection",

                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),

                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),

                      borderRadius: BorderRadius.circular(10),
                    ),

                    child: const Row(
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),

                        SizedBox(width: 6),

                        Text(
                          "Forecast",

                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 280,

                child: forecastList.isEmpty
                    ? const Center(child: Text("No forecast data available"))
                    : LineChart(
                        LineChartData(
                          minY: minY,
                          maxY: maxY,

                          borderData: FlBorderData(show: false),

                          gridData: FlGridData(
                            show: true,

                            drawVerticalLine: false,

                            horizontalInterval: ((maxY - minY) / 4).clamp(
                              1,
                              10,
                            ),

                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: const Color(0xFFF3F4F6),

                                strokeWidth: 1,
                              );
                            },
                          ),

                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),

                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),

                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,

                                reservedSize: 38,

                                interval: ((maxY - minY) / 4).clamp(1, 10),

                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toInt().toString(),

                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ),

                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,

                                reservedSize: 30,

                                interval: 1,

                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();

                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),

                                    child: Text(
                                      "D${idx + 1}",

                                      style: const TextStyle(
                                        fontSize: 11,

                                        color: Color(0xFF6B7280),

                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          lineBarsData: [
                            LineChartBarData(
                              spots: forecastList
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(e.key.toDouble(), e.value))
                                  .toList(),

                              isCurved: true,

                              curveSmoothness: 0.35,

                              barWidth: 3,

                              color: const Color(0xFF2563EB),

                              dotData: FlDotData(
                                show: true,

                                getDotPainter: (spot, percent, bar, index) {
                                  return FlDotCirclePainter(
                                    radius: 4,

                                    color: Colors.white,

                                    strokeWidth: 2,

                                    strokeColor: const Color(0xFF2563EB),
                                  );
                                },
                              ),

                              belowBarData: BarAreaData(
                                show: true,

                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,

                                  end: Alignment.bottomCenter,

                                  colors: [
                                    const Color(0xFF2563EB).withOpacity(0.18),

                                    const Color(0xFF2563EB).withOpacity(0),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipRoundedRadius: 10,

                              fitInsideHorizontally: true,

                              fitInsideVertically: true,

                              getTooltipItems: (spots) {
                                return spots.map((spot) {
                                  return LineTooltipItem(
                                    "Day ${spot.x.toInt() + 1}\n",

                                    const TextStyle(
                                      color: Colors.white70,

                                      fontSize: 11,
                                    ),

                                    children: [
                                      TextSpan(
                                        text:
                                            "${spot.y.toStringAsFixed(1)} units",

                                        style: const TextStyle(
                                          color: Colors.white,

                                          fontWeight: FontWeight.bold,

                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  );
                                }).toList();
                              },
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        
        //  AI INSIGHT CARD
        
        Container(
          width: double.infinity,

          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFF0F7FF), Colors.white],
            ),

            borderRadius: BorderRadius.circular(20),

            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Icon(
                  Icons.auto_awesome,

                  color: Colors.white,
                  size: 18,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Text(
                      "AI Business Insight",

                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF1E40AF),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      explanation,

                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  
  //  KPI CARD
 

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),

            blurRadius: 20,

            offset: const Offset(0, 8),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Expanded(
                child: Text(
                  title,

                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(8),

                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),

                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            value,

            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,

            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
