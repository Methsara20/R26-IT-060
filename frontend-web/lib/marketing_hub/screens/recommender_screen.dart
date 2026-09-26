import '../core/widgets/glass_card.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/inventory_service.dart';
import '../services/recommender_service.dart';

class RecommenderScreen extends StatefulWidget {
  const RecommenderScreen({super.key});

  @override
  State<RecommenderScreen> createState() => _RecommenderScreenState();
}

class _RecommenderScreenState extends State<RecommenderScreen> {
  final ageGroups = const ['18-25', '26-34', '35-45', '46-60'];
  final genders = const ['Female', 'Male'];
  final loyaltyTiers = const ['Bronze', 'Silver', 'Gold', 'Platinum'];
  final channels = const ['App Push', 'Email', 'In-Store', 'SMS'];
  final categories = const ['Coat', 'Dress', 'Handbag', 'Jewellery', 'Perfume', 'Shoes', 'Sunglasses', 'Top', 'Trousers', 'Watch'];
  final inventorySegments = const ['Women', 'Men', 'Kids', 'Footwear', 'Accessories'];

  String ageGroup = '26-34';
  String gender = 'Female';
  String loyaltyTier = 'Gold';
  String channel = 'App Push';
  String category = 'Dress';
  String inventorySegment = 'Women';
  bool isSeasonalWindow = false;
  bool isSalaryCycle = false;
  bool isSchoolHoliday = false;

  double visitFrequency = 8;
  double totalSpend = 45000;
  double avgBasket = 5000;
  double daysSinceLastPurchase = 14;
  double pastRedemptionRate = 40;
  double discountPct = 20;

  bool loading = false;
  String? errorMessage;
  List<dynamic>? rankedOffers;
  Timer? _debounce;

  List<dynamic>? inventoryMatches;
  bool loadingInventory = false;

  @override
  void initState() {
    super.initState();
    getRecommendation();
    fetchInventoryMatches();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleUpdate() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), getRecommendation);
  }

  Future<void> getRecommendation() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await RecommenderService.getRecommendation({
        'age_group': ageGroup,
        'gender': gender,
        'loyalty_tier': loyaltyTier,
        'channel': channel,
        'preferred_category': category,
        'visit_frequency': visitFrequency,
        'total_spend_lkr': totalSpend,
        'avg_basket_value_lkr': avgBasket,
        'days_since_last_purchase': daysSinceLastPurchase,
        'customer_past_redemption_rate': pastRedemptionRate / 100,
        'discount_pct': discountPct,
        'is_seasonal_window': isSeasonalWindow ? 1 : 0,
        'is_salary_cycle': isSalaryCycle ? 1 : 0,
        'is_school_holiday': isSchoolHoliday ? 1 : 0,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          rankedOffers = data['all_offers_ranked'];
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

  Future<void> fetchInventoryMatches() async {
    setState(() => loadingInventory = true);
    try {
      final response = await InventoryService.fetchMarketingOpportunities(category: inventorySegment, limit: '5');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          inventoryMatches = data['error'] == null ? data['opportunities'] : null;
          loadingInventory = false;
        });
      } else {
        setState(() {
          inventoryMatches = null;
          loadingInventory = false;
        });
      }
    } catch (e) {
      setState(() {
        inventoryMatches = null;
        loadingInventory = false;
      });
    }
  }

  String _daysLabel(double days) {
    if (days < 7) return '${days.round()} days ago';
    if (days < 60) return '${(days / 7).round()} weeks ago';
    return '${(days / 30).round()} months ago';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

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
                  colors: [Color(0xFFA78BFA), AppColors.primaryBlue]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            const Text('AI Promotion Recommender', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: isWide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildInputsCard()),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildResultsCard()),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildInputsCard(),
                  const SizedBox(height: 20),
                  _buildResultsCard(),
                ],
              ),
      ),
    );
  }

  Widget _buildInputsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Segment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _dropdownRow('Age Group', ageGroup, ageGroups, (v) { setState(() => ageGroup = v!); _scheduleUpdate(); }),
          _dropdownRow('Gender', gender, genders, (v) { setState(() => gender = v!); _scheduleUpdate(); }),
          _dropdownRow('Loyalty Tier', loyaltyTier, loyaltyTiers, (v) { setState(() => loyaltyTier = v!); _scheduleUpdate(); }),
          _dropdownRow('Channel', channel, channels, (v) { setState(() => channel = v!); _scheduleUpdate(); }),
          _dropdownRow('Preferred Category', category, categories, (v) { setState(() => category = v!); _scheduleUpdate(); }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Behavioural Signals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),

          _sliderRow('Visit Frequency', '${visitFrequency.round()} visits', visitFrequency, 0, 30, 30,
              (v) { setState(() => visitFrequency = v); _scheduleUpdate(); }),
          _sliderRow('Total Spend', 'LKR ${totalSpend.round()}', totalSpend, 0, 200000, 40,
              (v) { setState(() => totalSpend = v); _scheduleUpdate(); }),
          _sliderRow('Avg Basket Value', 'LKR ${avgBasket.round()}', avgBasket, 0, 20000, 40,
              (v) { setState(() => avgBasket = v); _scheduleUpdate(); }),
          _sliderRow('Last Purchase', _daysLabel(daysSinceLastPurchase), daysSinceLastPurchase, 0, 180, 36,
              (v) { setState(() => daysSinceLastPurchase = v); _scheduleUpdate(); }),
          _sliderRow('Past Redemption Rate', '${pastRedemptionRate.round()}%', pastRedemptionRate, 0, 100, 20,
              (v) { setState(() => pastRedemptionRate = v); _scheduleUpdate(); }),
          _sliderRow('Discount to Offer', '${discountPct.round()}%', discountPct, 0, 50, 10,
              (v) { setState(() => discountPct = v); _scheduleUpdate(); }),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Text('Inventory Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Checks live overstocked items from the Inventory component — separate from the model, for reference only.', style: TextStyle(fontSize: 11)),
          const SizedBox(height: 10),
          _dropdownRow('Target Segment', inventorySegment, inventorySegments, (v) {
            setState(() => inventorySegment = v!);
            fetchInventoryMatches();
          }),
          _buildInventoryNote(),
        ],
      ),
    );
  }

  Widget _buildInventoryNote() {
    if (loadingInventory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (inventoryMatches == null || inventoryMatches!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.scaffoldBackground, borderRadius: BorderRadius.circular(8)),
        child: const Text('No overstocked items currently flagged for this segment.', style: TextStyle(fontSize: 12)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.infoBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.goldAccent)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.goldAccent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${inventoryMatches!.length} overstocked item(s) in $inventorySegment — consider featuring:',
                  style: const TextStyle(fontSize: 12, color: AppColors.goldAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...inventoryMatches!.take(5).map((item) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${item['product_name'] ?? '-'} (${item['brand'] ?? '-'}) — +${item['excess_quantity'] ?? '-'} excess, Store ${item['store_id'] ?? '-'}',
                  style: const TextStyle(fontSize: 12),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Recommendation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Updates automatically as you adjust the inputs.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.errorBackground, borderRadius: BorderRadius.circular(8)),
              child: Text(errorMessage!, style: TextStyle(color: AppColors.errorText, fontSize: 13)),
            )
          else if (rankedOffers != null)
            _buildResultsContent()
          else
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          Text('Timing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Seasonal window (Mar-Apr, Jun-Jul, Nov, Dec)', style: TextStyle(fontSize: 13)),
            value: isSeasonalWindow,
            onChanged: (v) { setState(() => isSeasonalWindow = v); _scheduleUpdate(); },
            activeThumbColor: AppColors.goldAccent,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Salary cycle (20th-1st)', style: TextStyle(fontSize: 13)),
            value: isSalaryCycle,
            onChanged: (v) { setState(() => isSalaryCycle = v); _scheduleUpdate(); },
            activeThumbColor: AppColors.goldAccent,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('School holiday (Apr, Aug, Dec)', style: TextStyle(fontSize: 13)),
            value: isSchoolHoliday,
            onChanged: (v) { setState(() => isSchoolHoliday = v); _scheduleUpdate(); },
            activeThumbColor: AppColors.goldAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    final top = rankedOffers!.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Glowing recommendation card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.goldAccent.withOpacity(0.2),
                AppColors.goldAccent.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.goldAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(color: AppColors.goldAccent.withOpacity(0.15), blurRadius: 20, spreadRadius: -4, offset: const Offset(0, 6)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.goldAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.goldAccent.withOpacity(0.4)),
                    ),
                    child: const Text('RECOMMENDED', style: TextStyle(color: AppColors.goldAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                  const Spacer(),
                  const Icon(Icons.psychology_rounded, color: AppColors.goldAccent, size: 18),
                ],
              ),
              const SizedBox(height: 10),
              Text(top['offer_type'], style: const TextStyle(color: AppColors.goldAccent, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.greenAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(top['probability'] * 100).toStringAsFixed(1)}% predicted redemption',
                  style: const TextStyle(color: AppColors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Section header
        Row(
          children: [
            Container(width: 3, height: 14, decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('All Offer Scores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 12),
        ...rankedOffers!.map((offer) {
          final isTop = offer['offer_type'] == top['offer_type'];
          final pct = (offer['probability'] * 100);
          final barColor = isTop ? AppColors.goldAccent : AppColors.slateAccent;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (isTop) const Icon(Icons.star_rounded, size: 12, color: AppColors.goldAccent),
                        if (isTop) const SizedBox(width: 4),
                        Text(offer['offer_type'],
                          style: TextStyle(fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13)),
                      ],
                    ),
                    Text('${pct.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 12, color: barColor, fontWeight: isTop ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.07),
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _dropdownRow(String label, String value, List<String> options, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        dropdownColor: AppColors.scaffoldBackground,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _sliderRow(String label, String valueLabel, double value, double min, double max, int divisions, void Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              Text(valueLabel, style: const TextStyle(fontSize: 13, color: AppColors.valueGold, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.goldAccent,
              thumbColor: AppColors.cardBackground,
              overlayColor: AppColors.goldAccent.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
