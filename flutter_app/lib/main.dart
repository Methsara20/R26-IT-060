import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'calendar_screen.dart';
import 'customer_intelligence_screen.dart';
import 'upload_screen.dart';

const String backendUrl = 'http://127.0.0.1:8000';

void main() {
  runApp(const SkyHighApp());
}

class SkyHighApp extends StatelessWidget {
  const SkyHighApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SkyHigh Marketing Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A2744),
          primary: const Color(0xFF1A2744),
          secondary: const Color(0xFFD4A853),
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF6EC),
      ),
      home: const RootNav(),
    );
  }
}

class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int currentIndex = 0;

  final screens = const [
    HubScreen(),
    UploadScreen(),
    RecommenderScreen(),
    PosterScreen(),
    InventoryInsightsScreen(),
    PromotionCalendarScreen(),
    CustomerIntelligenceScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFD4A853).withOpacity(0.25),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Hub'),
          NavigationDestination(icon: Icon(Icons.upload_outlined), selectedIcon: Icon(Icons.upload), label: 'Upload'),
          NavigationDestination(icon: Icon(Icons.recommend_outlined), selectedIcon: Icon(Icons.recommend), label: 'Recommender'),
          NavigationDestination(icon: Icon(Icons.image_outlined), selectedIcon: Icon(Icons.image), label: 'Poster'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Inventory'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendar'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Customers'),
        ],
      ),
    );
  }
}

class HubScreen extends StatefulWidget {
  const HubScreen({super.key});

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  Map<String, dynamic>? kpis;
  bool loading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchKpis();
  }

  Future<void> fetchKpis() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('$backendUrl/kpis')).timeout(const Duration(seconds: 10));
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
        errorMessage = 'Could not reach the backend at $backendUrl.\nMake sure it is running.\n\n$e';
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
            const Text('Executive Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
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
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1A2744), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFD4A853)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Total campaigns analysed: ${kpis?['total_campaigns'] ?? '-'}', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE5D0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B5B3E), fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ],
      ),
    );
  }
}

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

  String ageGroup = '26-34';
  String gender = 'Female';
  String loyaltyTier = 'Gold';
  String channel = 'App Push';
  String category = 'Dress';
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

  @override
  void initState() {
    super.initState();
    getRecommendation();
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
      final response = await http
          .post(
            Uri.parse('$backendUrl/recommend'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
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
            }),
          )
          .timeout(const Duration(seconds: 15));

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

  String _daysLabel(double days) {
    if (days < 7) return '${days.round()} days ago';
    if (days < 60) return '${(days / 7).round()} weeks ago';
    return '${(days / 30).round()} months ago';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
        title: const Text('Promotion Recommender'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE5D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Segment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 12),
          _dropdownRow('Age Group', ageGroup, ageGroups, (v) { setState(() => ageGroup = v!); _scheduleUpdate(); }),
          _dropdownRow('Gender', gender, genders, (v) { setState(() => gender = v!); _scheduleUpdate(); }),
          _dropdownRow('Loyalty Tier', loyaltyTier, loyaltyTiers, (v) { setState(() => loyaltyTier = v!); _scheduleUpdate(); }),
          _dropdownRow('Channel', channel, channels, (v) { setState(() => channel = v!); _scheduleUpdate(); }),
          _dropdownRow('Preferred Category', category, categories, (v) { setState(() => category = v!); _scheduleUpdate(); }),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Behavioural Signals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
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
          const SizedBox(height: 4),
          const Text('Timing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Seasonal window (Mar-Apr, Jun-Jul, Nov, Dec)', style: TextStyle(fontSize: 13)),
            value: isSeasonalWindow,
            onChanged: (v) { setState(() => isSeasonalWindow = v); _scheduleUpdate(); },
            activeColor: const Color(0xFFD4A853),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Salary cycle (20th-1st)', style: TextStyle(fontSize: 13)),
            value: isSalaryCycle,
            onChanged: (v) { setState(() => isSalaryCycle = v); _scheduleUpdate(); },
            activeColor: const Color(0xFFD4A853),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('School holiday (Apr, Aug, Dec)', style: TextStyle(fontSize: 13)),
            value: isSchoolHoliday,
            onChanged: (v) { setState(() => isSchoolHoliday = v); _scheduleUpdate(); },
            activeColor: const Color(0xFFD4A853),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE5D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Recommendation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
              const Spacer(),
              if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Updates automatically as you adjust the inputs.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
            )
          else if (rankedOffers != null)
            _buildResultsContent()
          else
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    final top = rankedOffers!.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2744),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4A853), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('RECOMMENDED PROMOTION', style: TextStyle(color: Color(0xFFC4A882), fontSize: 12, letterSpacing: 1)),
              const SizedBox(height: 8),
              Text(top['offer_type'], style: const TextStyle(color: Color(0xFFD4A853), fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Predicted redemption probability: ${(top['probability'] * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('All Offer Scores', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
        const SizedBox(height: 8),
        ...rankedOffers!.map((offer) {
          final isTop = offer['offer_type'] == top['offer_type'];
          final pct = (offer['probability'] * 100);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${offer['offer_type']}${isTop ? ' *' : ''}',
                    style: TextStyle(fontWeight: isTop ? FontWeight.bold : FontWeight.normal, color: const Color(0xFF1A2744), fontSize: 13)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEDE5D0),
                    color: isTop ? const Color(0xFFD4A853) : const Color(0xFF1A2744),
                  ),
                ),
                Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: Colors.grey)),
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
              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF1A2744), fontWeight: FontWeight.w500)),
              Text(valueLabel, style: const TextStyle(fontSize: 13, color: Color(0xFFB4863A), fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFFD4A853),
              thumbColor: const Color(0xFF1A2744),
              overlayColor: const Color(0xFFD4A853).withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

// ── Poster Generator Screen ───────────────────────────────────
class PosterScreen extends StatefulWidget {
  const PosterScreen({super.key});

  @override
  State<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends State<PosterScreen> {
  final apiUrlController = TextEditingController();

  final genders = const ['Female', 'Male', 'Non-binary'];
  final ageGroups = const ['18-25', '26-34', '35-45', '46-60', '60+'];
  final offerTypes = const ['Seasonal Sale', 'Discount', 'Buy One Get One Free', 'Loyalty Reward', 'New Arrival', 'Flash Sale', 'Members Only'];
  final discountValues = const ['10% OFF', '20% OFF', '30% OFF', '40% OFF', '50% OFF', '60% OFF', 'BOGO FREE', 'Free Shipping'];
  final seasons = const ['Summer 2026', 'Winter 2026', 'Spring 2026', 'Autumn 2026', 'Year Round', 'Holiday Special', 'Back to School', 'Black Friday'];
  final allItems = const ['Dresses', 'Handbags', 'Shoes', 'Accessories', 'Jewellery', 'Tops & Blouses', 'Trousers', 'Coats & Jackets', 'Sportswear', 'Swimwear'];
  final palettes = const ['Pastel Pink & Gold', 'Bold Red & Black', 'Ocean Blue & White', 'Earthy Beige & Brown', 'Vibrant Yellow & Purple', 'Midnight Navy & Gold'];
  final styles = const ['Illustrated cartoon', 'Watercolour illustration', 'Bold graphic / pop art', 'Flat vector design', 'Fashion magazine editorial', 'Vintage retro poster'];

  String gender = 'Female';
  String ageGroup = '35-45';
  String offerType = 'Seasonal Sale';
  String discountValue = '30% OFF';
  String season = 'Summer 2026';
  Set<String> selectedItems = {'Dresses', 'Handbags'};
  String palette = 'Pastel Pink & Gold';
  String style = 'Illustrated cartoon';
  final brandController = TextEditingController(text: 'SkyHigh');

  bool? colabConnected;
  String? colabMessage;
  bool checkingConnection = false;
  bool generating = false;
  String? errorMessage;
  Uint8List? posterImageBytes;

  Future<void> checkConnection() async {
    if (apiUrlController.text.isEmpty) return;
    setState(() {
      checkingConnection = true;
      colabConnected = null;
    });
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/poster/health?api_url=${Uri.encodeComponent(apiUrlController.text)}'))
          .timeout(const Duration(seconds: 10));
      final data = json.decode(response.body);
      setState(() {
        colabConnected = data['connected'];
        colabMessage = data['message'];
        checkingConnection = false;
      });
    } catch (e) {
      setState(() {
        colabConnected = false;
        colabMessage = 'Could not reach backend: $e';
        checkingConnection = false;
      });
    }
  }

  Future<void> generatePoster() async {
    if (apiUrlController.text.isEmpty) {
      setState(() => errorMessage = 'Paste your Colab ngrok URL first.');
      return;
    }
    if (selectedItems.isEmpty) {
      setState(() => errorMessage = 'Select at least one item.');
      return;
    }

    setState(() {
      generating = true;
      errorMessage = null;
      posterImageBytes = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$backendUrl/poster/generate'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'api_url': apiUrlController.text,
              'gender': gender,
              'age_group': ageGroup,
              'offer_type': offerType,
              'discount_value': discountValue,
              'season': season,
              'items': selectedItems.toList(),
              'palette': palette,
              'style': style,
              'brand_name': brandController.text,
            }),
          )
          .timeout(const Duration(seconds: 190));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          posterImageBytes = base64Decode(data['image_b64']);
          generating = false;
        });
      } else {
        final body = json.decode(response.body);
        setState(() {
          errorMessage = body['detail'] ?? 'Something went wrong (${response.statusCode})';
          generating = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error generating poster: $e';
        generating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
        title: const Text('Poster Generator'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: isWide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildForm()),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: _buildPreview()),
                  ],
                ),
              )
            : Column(
                children: [
                  _buildForm(),
                  const SizedBox(height: 20),
                  _buildPreview(),
                ],
              ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE5D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Colab Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD4A853))),
            child: const Text(
              'Open your Colab notebook, run all cells, and paste the ngrok URL below.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B5B3E)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: apiUrlController,
            decoration: const InputDecoration(labelText: 'Colab ngrok URL', hintText: 'https://xxxx.ngrok-free.app', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: checkingConnection ? null : checkConnection,
              icon: checkingConnection ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi),
              label: const Text('Check Connection'),
            ),
          ),
          if (colabConnected != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(colabConnected! ? Icons.check_circle : Icons.error, color: colabConnected! ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(colabMessage ?? '', style: const TextStyle(fontSize: 12))),
              ],
            ),
          ],

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Customer Segment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 8),
          _dropdown('Gender', gender, genders, (v) => setState(() => gender = v!)),
          _dropdown('Age Group', ageGroup, ageGroups, (v) => setState(() => ageGroup = v!)),

          const SizedBox(height: 12),
          const Text('Offer Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 8),
          _dropdown('Offer Type', offerType, offerTypes, (v) => setState(() => offerType = v!)),
          _dropdown('Discount', discountValue, discountValues, (v) => setState(() => discountValue = v!)),
          _dropdown('Season / Campaign', season, seasons, (v) => setState(() => season = v!)),

          const SizedBox(height: 12),
          const Text('Items for Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: allItems.map((item) {
              final selected = selectedItems.contains(item);
              return FilterChip(
                label: Text(item, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: const Color(0xFFD4A853).withOpacity(0.3),
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      selectedItems.add(item);
                    } else {
                      selectedItems.remove(item);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 12),
          const Text('Visual Style', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 8),
          _dropdown('Colour Palette', palette, palettes, (v) => setState(() => palette = v!)),
          _dropdown('Illustration Style', style, styles, (v) => setState(() => style = v!)),
          const SizedBox(height: 12),
          TextField(
            controller: brandController,
            decoration: const InputDecoration(labelText: 'Brand name', border: OutlineInputBorder(), isDense: true),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: generating ? null : generatePoster,
              icon: generating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(generating ? 'Generating... (30-90s)' : 'Generate Poster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2744),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDE5D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          const SizedBox(height: 16),
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Text(errorMessage!, style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
            )
          else if (posterImageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(posterImageBytes!, fit: BoxFit.contain),
            )
          else
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFFAF6EC), borderRadius: BorderRadius.circular(8)),
              child: const Column(
                children: [
                  Icon(Icons.image_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('Your generated poster will appear here', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String value, List<String> options, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

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
      final query = selectedCategory == 'All' ? '' : '?category=$selectedCategory';
      final response = await http
          .get(Uri.parse('$backendUrl/inventory/overstock-suggestions$query'))
          .timeout(const Duration(seconds: 10));

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
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
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
              decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD4A853))),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF6B5B3E)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Live overstock data from the Inventory component — read-only. Consider featuring these in your next promotion.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B5B3E)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Category:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1A2744))),
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
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(errorMessage!, style: TextStyle(color: Colors.red.shade900)),
              )
            else if (suggestions != null && suggestions!.isNotEmpty) ...[
              if (lastUpdated != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Last updated: $lastUpdated', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              ...suggestions!.map((item) => _buildSuggestionCard(item)),
            ] else if (!loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No overstocked items found for this category.', style: TextStyle(color: Colors.grey)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEDE5D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFD4A853).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text('+${item['excess_units']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['product_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
                const SizedBox(height: 2),
                Text('${item['brand']} · ${item['category']} · Store ${item['store_id']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${item['current_stock']} in stock', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('reorder at ${item['reorder_level']}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}