import '../core/widgets/glass_card.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/inventory_service.dart';

// ── Inventory Insights Screen (read-only view into teammate's overstock data) ──
class InventoryInsightsScreen extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onCreatePoster;

  const InventoryInsightsScreen({super.key, this.onCreatePoster});

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
      final response = await InventoryService.fetchMarketingOpportunities(
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
            suggestions = data['opportunities'];
            lastUpdated = suggestions!.isEmpty ? null : suggestions!.first['created_at'];
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        title: Row(
          children: [
            Container(width: 3, height: 20,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.greenAccent, AppColors.goldAccent]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text('Inventory Insights', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: fetchSuggestions, tooltip: 'Refresh',
            style: IconButton.styleFrom(foregroundColor: AppColors.textMuted)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.goldAccent.withOpacity(0.12), AppColors.greenAccent.withOpacity(0.05)],
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.goldAccent.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.goldAccent),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Live marketing opportunities from the Inventory component — read-only. Consider featuring these in your next promotion.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Category pills
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter by Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((c) {
                    final isSelected = selectedCategory == c;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () { setState(() => selectedCategory = c); fetchSuggestions(); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: isSelected ? LinearGradient(
                              colors: [AppColors.goldAccent, AppColors.goldAccent.withOpacity(0.7)],
                            ) : null,
                            color: isSelected ? null : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isSelected ? AppColors.goldAccent : Colors.white.withOpacity(0.12)),
                          ),
                          child: Text(c, style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.scaffoldBackground : AppColors.textMuted,
                          )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (loading) const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(backgroundColor: Colors.transparent, valueColor: AlwaysStoppedAnimation(AppColors.goldAccent)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.errorBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.urgentAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.errorText, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(errorMessage!, style: TextStyle(color: AppColors.errorText))),
                  ],
                ),
              )
            else if (suggestions != null && suggestions!.isNotEmpty) ...[
              if (lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Last updated: $lastUpdated', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ...suggestions!.map((item) => _buildSuggestionCard(item)),
            ] else if (!loading)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      const Icon(Icons.inbox_rounded, size: 40, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text('No marketing opportunities found for this category.',
                        style: TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(dynamic item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: widget.onCreatePoster == null ? null : () => widget.onCreatePoster!(Map<String, dynamic>.from(item as Map)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.goldAccent.withOpacity(0.3), AppColors.goldAccent.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text('+${item['excess_quantity']}', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.goldAccent, fontSize: 16)),
                  const Text('excess', style: TextStyle(fontSize: 9, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(child: Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      if (item['product_id'] != null) Text('#${item['product_id']}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace')),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _pill(item['brand'] ?? '', AppColors.blueAccent),
                      const SizedBox(width: 4),
                      _pill(item['category'] ?? '', AppColors.textMuted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${item['current_stock']} units', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('LKR ${item['selling_price']}', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primaryBlue, AppColors.primaryBlue.withOpacity(0.7)]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_rounded, size: 12, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Create Poster', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
