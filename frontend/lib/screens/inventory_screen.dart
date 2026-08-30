import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/inventory_service.dart';

// ── Inventory Insights Screen (read-only view into teammate's overstock data) ──
class InventoryInsightsScreen extends StatefulWidget {
  const InventoryInsightsScreen({super.key});

  @override
  State<InventoryInsightsScreen> createState() => _InventoryInsightsScreenState();
}

class _InventoryInsightsScreenState extends State<InventoryInsightsScreen> {
  final categories = const ['All', 'Women', 'Men', 'Kids', 'Footwear', 'Accessories'];
  String selectedCategory = 'All';

  bool loading = true;
  String? errorMessage;
  List<dynamic>? suggestions;
  String? lastUpdated;

  @override
  void initState() {
    super.initState();
    fetchSuggestions();
  }

  Future<void> fetchSuggestions() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await InventoryService.fetchOverstockSuggestions(
        category: selectedCategory == 'All' ? null : selectedCategory,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] != null) {
          setState(() {
            errorMessage = data['error'];
            loading = false;
          });
        } else {
          setState(() {
            suggestions = data['suggestions'];
            lastUpdated = data['last_updated'];
            loading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Something went wrong (${response.statusCode})';
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
        title: const Text('Inventory Insights'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: fetchSuggestions, tooltip: 'Refresh')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.infoBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.goldAccent)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live overstock data from the Inventory component — read-only. Consider featuring these in your next promotion.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Category:', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: selectedCategory,
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    setState(() => selectedCategory = v!);
                    fetchSuggestions();
                  },
                ),
                const Spacer(),
                if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.errorBackground, borderRadius: BorderRadius.circular(8)),
                child: Text(errorMessage!, style: TextStyle(color: AppColors.errorText)),
              )
            else if (suggestions != null && suggestions!.isNotEmpty) ...[
              if (lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Last updated: $lastUpdated', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ),
              ...suggestions!.map((item) => _buildSuggestionCard(item)),
            ] else if (!loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No overstocked items found for this category.', style: TextStyle(color: AppColors.textMuted)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.goldAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('+${item['excess_units']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text('${item['brand']} · ${item['category']} · Store ${item['store_id']}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${item['current_stock']} in stock', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('reorder at ${item['reorder_level']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
