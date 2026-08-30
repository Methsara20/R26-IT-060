import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'core/constants/api_constants.dart';

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
      final response = await http
          .get(Uri.parse('$backendUrl/customer-intelligence?at_risk_days=${atRiskThreshold.round()}'))
          .timeout(const Duration(seconds: 15));

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
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
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
            const Icon(Icons.wifi_off, size: 48, color: Colors.redAccent),
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
            const Text('How Customers Are Segmented', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
            const SizedBox(height: 8),
            _infoCard('Loyalty Tier', 'Customers are grouped into Bronze, Silver, Gold, and Platinum based on cumulative spend and engagement. Higher tiers are prioritised for retention-focused offers.'),
            _infoCard('New vs. Returning', 'Customers who joined in the last 90 days, or have only made one visit, are classified as New. This affects which offers suit them best.'),
            _infoCard('Purchase Intent Score', 'A 0-100 score combining recency, frequency, and monetary value (RFM). Higher scores flag customers most likely to respond to an active promotion right now.'),

            const SizedBox(height: 24),
            const Text('New vs. Returning Customers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
            const SizedBox(height: 12),
            if (data?['new_vs_returning'] != null) _buildBarSection(Map<String, dynamic>.from(data!['new_vs_returning']), const Color(0xFF7AA6C2)),

            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Segment Breakdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
              ],
            ),
            const SizedBox(height: 12),
            if (data?['by_loyalty_tier'] != null) ...[
              const Text('By Loyalty Tier', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              _buildBarSection(Map<String, dynamic>.from(data!['by_loyalty_tier']), const Color(0xFF1A2744)),
              const SizedBox(height: 16),
            ],
            if (data?['by_age_group'] != null) ...[
              const Text('By Age Group', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              _buildBarSection(Map<String, dynamic>.from(data!['by_age_group']), const Color(0xFFD4A853)),
            ],

            const SizedBox(height: 24),
            const Text('Disengagement Risk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Inactive for more than: ', style: TextStyle(fontSize: 13)),
                Text('${atRiskThreshold.round()} days', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFB4863A))),
              ],
            ),
            Slider(
              value: atRiskThreshold,
              min: 30,
              max: 180,
              divisions: 15,
              activeColor: const Color(0xFFD4A853),
              onChanged: (v) => setState(() => atRiskThreshold = v),
              onChangeEnd: (v) => fetchData(),
            ),
            if (data?['at_risk_count'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade200)),
                child: Text(
                  '${data!['at_risk_count']} customers (${data!['at_risk_pct']}%) haven\'t purchased in over ${atRiskThreshold.round()} days.',
                  style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
                ),
              ),
            if (data?['at_risk_by_tier'] != null) ...[
              const SizedBox(height: 12),
              _buildBarSection(Map<String, dynamic>.from(data!['at_risk_by_tier']), const Color(0xFFB4543A)),
            ],

            const SizedBox(height: 24),
            const Text('Purchase Intent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _kpiCard('Avg Intent Score', '${data?['avg_intent_score'] ?? '-'}/100', ''),
                _kpiCard('High-Intent Customers', '${data?['high_intent_count'] ?? '-'}', 'good targets for active promotion'),
              ],
            ),
            const SizedBox(height: 12),
            if (data?['intent_distribution'] != null) _buildBarSection(Map<String, dynamic>.from(data!['intent_distribution']), const Color(0xFF4A7C59)),

            const SizedBox(height: 24),
            const Text('Top 10 Highest-Intent Customers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
            const SizedBox(height: 8),
            if (data?['top_intent_customers'] != null) _buildCustomerTable(data!['top_intent_customers'], showIntent: true),

            const SizedBox(height: 24),
            const Text('Top Customers by Value', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
            const SizedBox(height: 8),
            if (data?['top_customers_by_value'] != null) _buildCustomerTable(data!['top_customers_by_value'], showSpend: true),
          ],
        ),
      ),
    );
  }

  String _fmtPct(dynamic v) => v == null ? '-' : '$v%';
  String _fmtNum(dynamic v) => v == null ? '-' : (v as num).toStringAsFixed(0);

  Widget _kpiCard(String label, String value, String sub) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE5D0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5B3E), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEDE5D0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2744), fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildBarSection(Map<String, dynamic> counts, Color color) {
    final maxVal = counts.values.fold<int>(0, (max, v) => (v as int) > max ? v : max);
    final entries = counts.entries.toList();

    return Column(
      children: entries.map((e) {
        final val = e.value as int;
        final frac = maxVal > 0 ? val / maxVal : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              SizedBox(width: 90, child: Text(e.key, style: const TextStyle(fontSize: 12, color: Color(0xFF1A2744)))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: frac, minHeight: 16, backgroundColor: const Color(0xFFEDE5D0), color: color),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(width: 40, child: Text('$val', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomerTable(List<dynamic> customers, {bool showIntent = false, bool showSpend = false}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFEDE5D0))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFFAF6EC)),
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
              if (showSpend) DataCell(Text((c['total_spend_lkr'] as num?)?.toStringAsFixed(0) ?? '-', style: const TextStyle(fontSize: 12))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}
