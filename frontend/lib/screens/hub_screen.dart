// Web downloads intentionally use dart:html because this application targets Flutter web.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/constants/api_constants.dart';
import '../core/theme/app_colors.dart';
import '../utils/formatters.dart';
import '../services/kpi_service.dart';
import '../services/calendar_service.dart';

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  Map<String, dynamic>? kpis;
  int? selectedRevenueIndex;
  bool loading = true;
  String? errorMessage;

  List<dynamic> tomorrowNotes = [];
  int tomorrowCampaignCount = 0;
  bool loadingTomorrow = false;

  // ── Dashboard date filter ──────────────────────────────
  String selectedFilter = 'This Year';
  DateTimeRange? customRange;
  final filterOptions = const ['Today', 'This Month', 'Last Month', 'This Year', 'Last Year', 'Custom'];

  // ── Report generation ──────────────────────────────────
  String reportPeriodType = 'yearly';
  List<String> availableYears = [];
  List<String> availableMonths = [];
  List<String> availableQuarters = [];
  Set<String> selectedReportPeriods = {};
  bool loadingPeriods = false;
  bool generatingReport = false;
  String? reportStatusMessage;
  bool? reportSuccess;

  @override
  void initState() {
    super.initState();
    fetchKpis();
    fetchTomorrowAlerts();
    fetchAvailablePeriods();
  }

  ({String? start, String? end}) _rangeForFilter(String filter) {
    final now = DateTime.now();
    String fmt(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    switch (filter) {
      case 'Today':
        return (start: fmt(now), end: fmt(now));
      case 'This Month':
        return (start: fmt(DateTime(now.year, now.month, 1)), end: fmt(now));
      case 'Last Month':
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDay = DateTime(now.year, now.month, 0);
        return (start: fmt(lastMonth), end: fmt(lastDay));
      case 'This Year':
        return (start: fmt(DateTime(now.year, 1, 1)), end: fmt(now));
      case 'Last Year':
        return (start: fmt(DateTime(now.year - 1, 1, 1)), end: fmt(DateTime(now.year - 1, 12, 31)));
      case 'Custom':
        if (customRange != null) {
          return (start: fmt(customRange!.start), end: fmt(customRange!.end));
        }
        return (start: null, end: null);
      default:
        return (start: null, end: null);
    }
  }

  Future<void> onFilterChanged(String filter) async {
    if (filter == 'Custom') {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2015),
        lastDate: DateTime.now(),
        initialDateRange: customRange ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 30)), end: DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppColors.goldAccent,
                    onPrimary: AppColors.scaffoldBackground,
                    surface: AppColors.cardBackground,
                    onSurface: AppColors.textPrimary,
                  ),
            ),
            child: child!,
          );
        },
      );
      if (picked == null) return; // user cancelled, keep previous filter
      setState(() {
        customRange = picked;
        selectedFilter = 'Custom';
      });
    } else {
      setState(() => selectedFilter = filter);
    }
    fetchKpis();
  }

  Future<void> fetchAvailablePeriods() async {
    setState(() => loadingPeriods = true);
    try {
      final response = await KpiService.fetchAvailablePeriods();
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          availableYears = List<String>.from(data['years'] ?? []);
          availableMonths = List<String>.from(data['months'] ?? []);
          availableQuarters = List<String>.from(data['quarters'] ?? []);
          loadingPeriods = false;
        });
      } else {
        setState(() => loadingPeriods = false);
      }
    } catch (e) {
      setState(() => loadingPeriods = false);
    }
  }

  List<String> get currentPeriodOptions {
    switch (reportPeriodType) {
      case 'yearly':
        return availableYears;
      case 'monthly':
        return availableMonths;
      case 'quarterly':
        return availableQuarters;
      default:
        return [];
    }
  }

  Future<void> downloadReport() async {
    if (selectedReportPeriods.isEmpty) {
      setState(() {
        reportSuccess = false;
        reportStatusMessage = 'Select at least one period first.';
      });
      return;
    }

    setState(() {
      generatingReport = true;
      reportStatusMessage = null;
      reportSuccess = null;
    });

    try {
      final response = await KpiService.generateReport(
        periodType: reportPeriodType,
        periods: selectedReportPeriods.toList(),
      );

      if (response.statusCode == 200) {
        final blob = html.Blob([response.bodyBytes], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', 'marketing_report.pdf')
          ..click();
        html.Url.revokeObjectUrl(url);
        setState(() {
          reportSuccess = true;
          reportStatusMessage = 'Report downloaded.';
          generatingReport = false;
        });
      } else {
        final body = json.decode(response.body);
        setState(() {
          reportSuccess = false;
          reportStatusMessage = body['detail'] ?? 'Something went wrong (${response.statusCode})';
          generatingReport = false;
        });
      }
    } catch (e) {
      setState(() {
        reportSuccess = false;
        reportStatusMessage = 'Could not reach the backend.\n\n$e';
        generatingReport = false;
      });
    }
  }

  Future<void> fetchTomorrowAlerts() async {
    setState(() => loadingTomorrow = true);
    try {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final year = tomorrow.year;
      final month = tomorrow.month;
      final day = tomorrow.day;

      final notesResp = await CalendarService.fetchNotes(year: year, month: month);
      final campaignsResp = await CalendarService.fetchCampaigns(year: year, month: month);

      List<dynamic> notesForTomorrow = [];
      if (notesResp.statusCode == 200) {
        final dateKey = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
        final allNotes = json.decode(notesResp.body) as List<dynamic>;
        notesForTomorrow = allNotes.where((n) => n['date'] == dateKey).toList();
      }

      int campaignCount = 0;
      if (campaignsResp.statusCode == 200) {
        final counts = json.decode(campaignsResp.body) as Map<String, dynamic>;
        campaignCount = (counts[day.toString()] as num?)?.toInt() ?? 0;
      }

      setState(() {
        tomorrowNotes = notesForTomorrow;
        tomorrowCampaignCount = campaignCount;
        loadingTomorrow = false;
      });
    } catch (e) {
      setState(() => loadingTomorrow = false);
    }
  }

  Future<void> fetchKpis() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final range = _rangeForFilter(selectedFilter);
      final response = await KpiService.fetchKpis(startDate: range.start, endDate: range.end);
      if (response.statusCode == 200) {
        setState(() {
          kpis = json.decode(response.body);
          loading = false;
        });
      } else {
        final body = json.decode(response.body);
        setState(() {
          errorMessage = body['detail'] ?? 'Something went wrong (${response.statusCode})';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'The dashboard request did not complete.\n'
            'The backend is at $backendUrl; its first request may take longer while data and the model load.\n\n$e';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Personalized Marketing Intelligence'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: fetchKpis, tooltip: 'Refresh')],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError()
              : _buildKpiDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: fetchKpis, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiDashboard() {
    return RefreshIndicator(
      onRefresh: fetchKpis,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Executive Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            _buildFilterBar(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _kpiCard('Revenue Uplift vs Control', _fmtPct(kpis?['revenue_uplift_vs_control_pct']), 'treatment vs control'),
                _kpiCard('Redemption Rate', _fmtPct(kpis?['redemption_rate']), 'overall'),
                _kpiCard('Best Offer Type', kpis?['best_offer_type'] ?? '-',
                    kpis?['best_offer_redemption_rate'] != null ? '${kpis!['best_offer_redemption_rate']}% redemption' : ''),
                _kpiCard('Best Channel', kpis?['best_channel'] ?? '-',
                    kpis?['best_channel_ctr'] != null ? '${kpis!['best_channel_ctr']}% CTR' : ''),
                _kpiCard('Total Customers', '${kpis?['total_customers'] ?? '-'}', 'in database'),
                _kpiCard('Model Accuracy', _fmtPct(kpis?['model_accuracy']), 'recommender confidence'),
                if (!loadingTomorrow && (tomorrowNotes.isNotEmpty || tomorrowCampaignCount > 0)) _buildTomorrowCard(),
              ],
            ),
            const SizedBox(height: 24),
            if (kpis?['offer_type_breakdown'] != null) ...[
              const Text('Redemption Rate by Offer Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              _buildBarChart(Map<String, dynamic>.from(kpis!['offer_type_breakdown']), AppColors.goldAccent),
              const SizedBox(height: 24),
            ],
            if (kpis?['channel_breakdown'] != null) ...[
              const Text('Click-Through Rate by Channel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              _buildBarChart(Map<String, dynamic>.from(kpis!['channel_breakdown']), AppColors.slateAccent),
              const SizedBox(height: 24),
            ],
            if (kpis?['revenue_over_time'] != null) ...[
              const Text('Revenue from Redeemed Campaigns Over Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              _buildRevenueLineChart(Map<String, dynamic>.from(kpis!['revenue_over_time'])),
              const SizedBox(height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.infoBackground, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.goldAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Total campaigns analysed: ${kpis?['total_campaigns'] ?? '-'}', style: const TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildReportSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: filterOptions.map((f) {
        final isSelected = selectedFilter == f;
        final label = f == 'Custom' && selectedFilter == 'Custom' && customRange != null
            ? '${customRange!.start.month}/${customRange!.start.day} – ${customRange!.end.month}/${customRange!.end.day}'
            : f;
        return ChoiceChip(
          label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? AppColors.scaffoldBackground : AppColors.textMuted)),
          selected: isSelected,
          selectedColor: AppColors.goldAccent,
          backgroundColor: AppColors.cardBackground,
          side: BorderSide(color: isSelected ? AppColors.goldAccent : AppColors.divider),
          onSelected: (_) => onFilterChanged(f),
        );
      }).toList(),
    );
  }

  Widget _buildReportSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Generate Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('Select one or more periods to include in a single PDF report — all KPIs and charts for each period.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['yearly', 'monthly', 'quarterly'].map((type) {
              final isSelected = reportPeriodType == type;
              return ChoiceChip(
                label: Text(type[0].toUpperCase() + type.substring(1), style: TextStyle(fontSize: 12, color: isSelected ? AppColors.scaffoldBackground : AppColors.textMuted)),
                selected: isSelected,
                selectedColor: AppColors.goldAccent,
                backgroundColor: AppColors.scaffoldBackground,
                side: BorderSide(color: isSelected ? AppColors.goldAccent : AppColors.divider),
                onSelected: (_) => setState(() {
                  reportPeriodType = type;
                  selectedReportPeriods = {};
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (loadingPeriods)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else if (currentPeriodOptions.isEmpty)
            const Text('No periods available yet.', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: currentPeriodOptions.map((period) {
                final isSelected = selectedReportPeriods.contains(period);
                return FilterChip(
                  label: Text(period, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  selectedColor: AppColors.goldAccent.withValues(alpha: 0.3),
                  backgroundColor: AppColors.scaffoldBackground,
                  side: BorderSide(color: isSelected ? AppColors.goldAccent : AppColors.divider),
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        selectedReportPeriods.add(period);
                      } else {
                        selectedReportPeriods.remove(period);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: generatingReport ? null : downloadReport,
              icon: generatingReport
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                  : const Icon(Icons.download),
              label: Text(generatingReport ? 'Generating...' : 'Download PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.goldAccent),
              ),
            ),
          ),
          if (reportStatusMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(reportSuccess == true ? Icons.check_circle : Icons.error, color: reportSuccess == true ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(reportStatusMessage!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTomorrowCard() {
    final hasUrgent = tomorrowCampaignCount > 0;
    final color = hasUrgent ? AppColors.urgentAccent : AppColors.goldAccent;
    final headline = hasUrgent
        ? '$tomorrowCampaignCount campaign(s) tomorrow'
        : '${tomorrowNotes.length} reminder(s) tomorrow';

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(hasUrgent ? Icons.campaign : Icons.event_note, size: 14, color: color),
              const SizedBox(width: 6),
              Text('Tomorrow', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(headline, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          if (tomorrowNotes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tomorrowNotes.first['text'] ?? '',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRevenueLineChart(Map<String, dynamic> data) {
    final labels = List<String>.from(data['labels'] ?? []);
    final values = List<num>.from(data['values'] ?? []);
    final topOfferTypes = data['top_offer_type'] != null ? List<dynamic>.from(data['top_offer_type']) : <dynamic>[];

    if (labels.isEmpty || values.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Text('Not enough data yet.', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
      );
    }

    final maxVal = values.fold<double>(0, (max, v) => v.toDouble() > max ? v.toDouble() : max);
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList();

    final labelInterval = (labels.length / 10).ceil().clamp(1, 100);

    String formatLabel(String yyyyMm) {
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final parts = yyyyMm.split('-');
      if (parts.length != 2) return yyyyMm;
      final monthIdx = int.tryParse(parts[1]) ?? 1;
      return "${monthNames[(monthIdx - 1).clamp(0, 11)]} '${parts[0].substring(2)}";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 260,
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider),
          ),
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxVal <= 0 ? 10 : maxVal * 1.2,
              lineTouchData: LineTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  if (response != null && response.lineBarSpots != null && response.lineBarSpots!.isNotEmpty) {
                    final idx = response.lineBarSpots!.first.spotIndex;
                    if (idx != selectedRevenueIndex) {
                      setState(() => selectedRevenueIndex = idx);
                    }
                  }
                },
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => AppColors.tooltipBackground,
                  getTooltipItems: (spots) => spots.map((s) {
                    final idx = s.x.toInt();
                    final label = idx >= 0 && idx < labels.length ? formatLabel(labels[idx]) : '';
                    return LineTooltipItem(
                      '$label\nLKR ${formatWithCommas(s.y)}',
                      const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                    );
                  }).toList(),
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 60, getTitlesWidget: (v, meta) => Text(formatWithCommas(v), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)))),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                      if (i % labelInterval != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(formatLabel(labels[i]), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.goldAccent,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                      radius: index == selectedRevenueIndex ? 6 : 4,
                      color: AppColors.goldAccent,
                      strokeWidth: index == selectedRevenueIndex ? 2 : 0,
                      strokeColor: AppColors.textPrimary,
                    ),
                  ),
                  belowBarData: BarAreaData(show: true, color: AppColors.goldAccent.withValues(alpha: 0.08)),
                ),
              ],
            ),
          ),
        ),
        if (selectedRevenueIndex != null && selectedRevenueIndex! >= 0 && selectedRevenueIndex! < labels.length) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.infoBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.goldAccent),
            ),
            child: Row(
              children: [
                const Icon(Icons.show_chart, size: 16, color: AppColors.goldAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatLabel(labels[selectedRevenueIndex!]),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Revenue: LKR ${formatWithCommas(values[selectedRevenueIndex!])}'
                        '${selectedRevenueIndex! < topOfferTypes.length && topOfferTypes[selectedRevenueIndex!] != null ? '  ·  Top offer: ${topOfferTypes[selectedRevenueIndex!]}' : ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBarChart(Map<String, dynamic> data, Color barColor) {
    final entries = data.entries.toList();
    final maxVal = entries.fold<double>(0, (max, e) => (e.value as num).toDouble() > max ? (e.value as num).toDouble() : max);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: BarChart(
        BarChartData(
          maxY: (maxVal * 1.2).clamp(10, 100),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, getTitlesWidget: (v, meta) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(entries[i].key, style: const TextStyle(fontSize: 10, color: AppColors.textPrimary), textAlign: TextAlign.center),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 20, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
          barGroups: entries.asMap().entries.map((e) {
            final idx = e.key;
            final val = (e.value.value as num).toDouble();
            return BarChartGroupData(
              x: idx,
              barRods: [BarChartRodData(toY: val, color: barColor, width: 22, borderRadius: BorderRadius.circular(4))],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _fmtPct(dynamic value) => value == null ? '-' : '$value%';

  Widget _kpiCard(String label, String value, String sub) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }
}
