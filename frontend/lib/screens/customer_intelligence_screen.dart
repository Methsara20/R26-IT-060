import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/theme/app_colors.dart';
import '../utils/formatters.dart';
import '../services/customer_service.dart';

class CustomerIntelligenceScreen extends StatefulWidget {
  const CustomerIntelligenceScreen({super.key});

  @override
  State<CustomerIntelligenceScreen> createState() => _CustomerIntelligenceScreenState();
}

class _CustomerIntelligenceScreenState extends State<CustomerIntelligenceScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? errorMessage;
  double atRiskThreshold = 60;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final response = await CustomerService.fetchCustomerIntelligence(atRiskDays: atRiskThreshold.round());

      if (response.statusCode == 200) {
        setState(() {
          data = json.decode(response.body);
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
        errorMessage = 'Could not reach the backend.\n\n$e';
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
        title: const Text('Customer Intelligence'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: fetchData, tooltip: 'Refresh')],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: AppColors.errorIcon),
            const SizedBox(height: 16),
            Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: fetchData, icon: const Icon(Icons.refresh), label: const Text('Try again')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: fetchData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top KPIs ──────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _kpiCard('Total Customers', '${data?['total_customers'] ?? '-'}', ''),
                _kpiCard('Gold/Platinum Share', _fmtPct(data?['gold_platinum_share']), ''),
                _kpiCard('Avg Spend (LKR)', _fmtNum(data?['avg_spend']), ''),
                _kpiCard('Avg Visit Frequency', '${data?['avg_visits'] ?? '-'}', ''),
              ],
            ),

            const SizedBox(height: 24),
            const Text('How Customers Are Segmented', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            _infoCard('Loyalty Tier', 'Customers are grouped into Bronze, Silver, Gold, and Platinum based on cumulative spend and engagement. Higher tiers are prioritised for retention-focused offers.'),
            _infoCard('New vs. Returning', 'Customers who joined in the last 90 days, or have only made one visit, are classified as New. This affects which offers suit them best.'),
            _infoCard('Purchase Intent Score', 'A 0-100 score combining recency, frequency, and monetary value (RFM). Higher scores flag customers most likely to respond to an active promotion right now.'),

            const SizedBox(height: 24),
            const Text('New vs. Returning Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            if (data?['new_vs_returning'] != null) _buildDonutChart(Map<String, dynamic>.from(data!['new_vs_returning'])),

            const SizedBox(height: 24),
            const Text('Segment Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final loyaltyChart = (data?['by_loyalty_tier'] != null)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('By Loyalty Tier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          _buildBarSection(Map<String, dynamic>.from(data!['by_loyalty_tier']), AppColors.loyaltyTierAccent),
                        ],
                      )
                    : const SizedBox.shrink();
                final ageChart = (data?['by_age_group'] != null)
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('By Age Group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textPrimary)),
                          const SizedBox(height: 8),
                          _buildBarSection(Map<String, dynamic>.from(data!['by_age_group']), AppColors.blueAccent),
                        ],
                      )
                    : const SizedBox.shrink();

                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: loyaltyChart),
                          const SizedBox(width: 16),
                          Expanded(child: ageChart),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          loyaltyChart,
                          const SizedBox(height: 16),
                          ageChart,
                        ],
                      );
              },
            ),

            const SizedBox(height: 24),
            const Text('Disengagement Risk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Inactive for more than: ', style: TextStyle(fontSize: 13)),
                Text('${atRiskThreshold.round()} days', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.valueGold)),
              ],
            ),
            Slider(
              value: atRiskThreshold,
              min: 30,
              max: 180,
              divisions: 15,
              activeColor: AppColors.goldAccent,
              onChanged: (v) => setState(() => atRiskThreshold = v),
              onChangeEnd: (v) => fetchData(),
            ),
            if (data?['at_risk_count'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.warningBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.goldAccent)),
                child: Text(
                  '${data!['at_risk_count']} customers (${data!['at_risk_pct']}%) haven\'t purchased in over ${atRiskThreshold.round()} days.',
                  style: const TextStyle(color: AppColors.warningText, fontSize: 13),
                ),
              ),
            if (data?['at_risk_by_tier'] != null) ...[
              const SizedBox(height: 12),
              _buildBarSection(Map<String, dynamic>.from(data!['at_risk_by_tier']), AppColors.urgentAccent),
            ],

            const SizedBox(height: 24),
            const Text('Purchase Intent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                final kpiColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _kpiCard('Avg Intent Score', '${data?['avg_intent_score'] ?? '-'}/100', ''),
                    const SizedBox(height: 16),
                    _kpiCard('High-Intent Customers', '${data?['high_intent_count'] ?? '-'}', 'good targets for active promotion'),
                  ],
                );
                final donutChart = (data?['intent_distribution'] != null)
                    ? _buildDonutChart(Map<String, dynamic>.from(data!['intent_distribution']))
                    : const SizedBox.shrink();

                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(width: 260, child: kpiColumn),
                          const SizedBox(width: 16),
                          Expanded(child: donutChart),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 16, runSpacing: 16, children: [
                            _kpiCard('Avg Intent Score', '${data?['avg_intent_score'] ?? '-'}/100', ''),
                            _kpiCard('High-Intent Customers', '${data?['high_intent_count'] ?? '-'}', 'good targets for active promotion'),
                          ]),
                          const SizedBox(height: 16),
                          donutChart,
                        ],
                      );
              },
            ),

            const SizedBox(height: 24),
            const Text('Top 10 Highest-Intent Customers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (data?['top_intent_customers'] != null) _buildCustomerTable(data!['top_intent_customers'], showIntent: true),

            const SizedBox(height: 24),
            const Text('Top Customers by Value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            if (data?['top_customers_by_value'] != null) _buildCustomerTable(data!['top_customers_by_value'], showSpend: true),
          ],
        ),
      ),
    );
  }

  String _fmtPct(dynamic v) => v == null ? '-' : '$v%';
  String _fmtNum(dynamic v) {
    if (v == null) return '-';
    return formatWithCommas((v as num));
  }

  Widget _kpiCard(String label, String value, String sub) {
    return Container(
      width: 220,
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
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildDonutChart(Map<String, dynamic> data) {
    final entries = data.entries.toList();
    final total = entries.fold<num>(0, (sum, e) => sum + (e.value as num));
    const palette = [AppColors.goldAccent, AppColors.blueAccent, AppColors.urgentAccent, AppColors.greenAccent, AppColors.neutralGrey];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 34,
                sections: entries.asMap().entries.map((e) {
                  final idx = e.key;
                  final val = (e.value.value as num).toDouble();
                  final pct = total > 0 ? (val / total * 100) : 0.0;
                  return PieChartSectionData(
                    value: val,
                    color: palette[idx % palette.length],
                    title: '${pct.toStringAsFixed(0)}%',
                    radius: 36,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                final idx = e.key;
                final key = e.value.key;
                final val = e.value.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[idx % palette.length], shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$key: $val', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarSection(Map<String, dynamic> counts, Color color) {
    final entries = counts.entries.toList();
    final maxVal = entries.fold<double>(0, (max, e) => (e.value as num).toDouble() > max ? (e.value as num).toDouble() : max);

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal <= 0 ? 10 : maxVal * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)))),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
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
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: AppColors.divider, strokeWidth: 1)),
          barGroups: entries.asMap().entries.map((e) {
            final idx = e.key;
            final val = (e.value.value as num).toDouble();
            return BarChartGroupData(
              x: idx,
              barRods: [BarChartRodData(toY: val, color: color, width: 22, borderRadius: BorderRadius.circular(4))],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCustomerTable(List<dynamic> customers, {bool showIntent = false, bool showSpend = false}) {
    return Container(
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(AppColors.scaffoldBackground),
          columns: [
            const DataColumn(label: Text('Customer ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataColumn(label: Text('Age Group', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            if (showIntent) const DataColumn(label: Text('Intent Score', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            if (showSpend) const DataColumn(label: Text('Spend (LKR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          ],
          rows: customers.map((c) {
            return DataRow(cells: [
              DataCell(Text('${c['customer_id'] ?? '-'}', style: const TextStyle(fontSize: 12))),
              DataCell(Text('${c['loyalty_tier'] ?? '-'}', style: const TextStyle(fontSize: 12))),
              DataCell(Text('${c['age_group'] ?? '-'}', style: const TextStyle(fontSize: 12))),
              if (showIntent) DataCell(Text('${c['intent_score'] ?? '-'} (${c['intent_bucket'] ?? ''})', style: const TextStyle(fontSize: 12))),
              if (showSpend) DataCell(Text(c['total_spend_lkr'] != null ? formatWithCommas(c['total_spend_lkr'] as num) : '-', style: const TextStyle(fontSize: 12))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
