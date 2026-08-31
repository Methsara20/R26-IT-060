import '../core/widgets/glass_card.dart';
// Web downloads intentionally use dart:html because this application targets Flutter web.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/poster_service.dart';
import '../widgets/poster/poster_history_tab.dart';
import '../widgets/poster/poster_scheduled_tab.dart';

// ── Poster Generator Screen ───────────────────────────────────
class PosterScreen extends StatefulWidget {
  final Map<String, dynamic>? inventoryOpportunity;

  const PosterScreen({super.key, this.inventoryOpportunity});

  @override
  State<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends State<PosterScreen> {
  final genders = const ['Female', 'Male', 'Non-binary', 'Unisex'];
  final ageGroups = const ['0-2', '3-5', '6-12', '13-18', '18-25', '26-34', '35-45', '46-60', '60+'];
  final offerTypes = const ['Not Applicable', 'Seasonal Sale', 'Discount', 'Buy One Get One Free', 'Loyalty Reward', 'New Arrival', 'Flash Sale', 'Members Only'];
  final discountValues = const ['Not Applicable', '10% OFF', '20% OFF', '30% OFF', '40% OFF', '50% OFF', '60% OFF', 'BOGO FREE', 'Free Shipping'];
  final seasons = const ['Summer 2026', 'Winter 2026', 'Spring 2026', 'Autumn 2026', 'Year Round', 'Holiday Special', 'Back to School', 'Black Friday'];
  final allItems = const ['Dresses', 'Handbags', 'Shoes', 'Accessories', 'Jewellery', 'Tops & Blouses', 'Trousers', 'Coats & Jackets', 'Sportswear', 'Swimwear', 'Kids Clothes'];
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
  final brandController = TextEditingController(text: 'Brand Name');
  final taglineController = TextEditingController();
  final inspirationController = TextEditingController();

  // Event Details (for in-store events/pop-ups) — all optional
  final eventDateController = TextEditingController();
  final eventTimeController = TextEditingController();
  final eventLocationController = TextEditingController();
  final validUntilController = TextEditingController();
  String hostingBranch = 'None';
  final hostingBranches = const ['None', 'Cool Planet - Nugegoda', 'Cool Planet - Maharagama', 'Cool Planet - Kandy', 'Cool Planet - Kirulapone', 'Cool Planet - Wattala', 'Cool Planet - Colombo', 'Cool Planet - Pelawatta', 'Cool Planet - Malabe'];
  bool includeTerms = false;

  bool generating = false;
  String? errorMessage;
  Uint8List? posterImageBytes;
  String? posterImageB64;

  final emailController = TextEditingController();
  final emailSubjectController = TextEditingController(text: 'Your Marketing Promotion Poster');
  bool sendingEmail = false;
  String? emailStatusMessage;
  bool? emailSuccess;

  DateTime? scheduledDate;
  bool scheduling = false;
  String? scheduleStatusMessage;
  bool? scheduleSuccess;

  @override
  void initState() {
    super.initState();
    final opportunity = widget.inventoryOpportunity;
    if (opportunity == null) return;

    final productName = (opportunity['product_name'] ?? '').toString();
    final category = (opportunity['category'] ?? '').toString();
    final subcategory = (opportunity['subcategory'] ?? '').toString();
    final searchableProduct = '$productName $category $subcategory'.toLowerCase();
    final matchingItem = allItems.cast<String?>().firstWhere(
          (item) => searchableProduct.contains(item!.toLowerCase()),
          orElse: () {
            if (searchableProduct.contains('kid')) return 'Kids Clothes';
            if (searchableProduct.contains('shoe') || searchableProduct.contains('footwear')) return 'Shoes';
            if (searchableProduct.contains('shirt') || searchableProduct.contains('top')) return 'Tops & Blouses';
            if (searchableProduct.contains('trouser') || searchableProduct.contains('pant')) return 'Trousers';
            if (searchableProduct.contains('accessor')) return 'Accessories';
            return null;
          },
        );
    if (matchingItem != null) selectedItems = {matchingItem};

    final brand = (opportunity['brand'] ?? '').toString().trim();
    if (brand.isNotEmpty) brandController.text = brand;
    inspirationController.text = [
      productName,
      if (opportunity['recommended_action'] != null) opportunity['recommended_action'].toString(),
    ].where((value) => value.trim().isNotEmpty).join('. ');
  }

  Future<void> generatePoster() async {
    if (selectedItems.isEmpty) {
      setState(() => errorMessage = 'Select at least one item.');
      return;
    }

    setState(() {
      generating = true;
      errorMessage = null;
      posterImageBytes = null;
      posterImageB64 = null;
      emailStatusMessage = null;
      emailSuccess = null;
    });

    try {
      final response = await PosterService.generatePoster({
        'gender': gender,
        'age_group': ageGroup,
        'offer_type': offerType,
        'discount_value': discountValue,
        'season': season,
        'items': selectedItems.toList(),
        'palette': palette,
        'style': style,
        'brand_name': brandController.text,
        'tagline': taglineController.text,
        'inspiration': inspirationController.text,
        'event_date': eventDateController.text,
        'event_time': eventTimeController.text,
        'event_location': eventLocationController.text,
        'valid_until': validUntilController.text,
        'hosting_branch': hostingBranch == 'None' ? '' : hostingBranch,
        'include_terms': includeTerms,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          posterImageB64 = data['image_b64'];
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

  void downloadPoster() {
    if (posterImageBytes == null) return;
    final blob = html.Blob([posterImageBytes!], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'marketing_poster_${DateTime.now().millisecondsSinceEpoch}.png')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> sendPosterEmail() async {
    if (posterImageB64 == null) {
      setState(() {
        emailSuccess = false;
        emailStatusMessage = 'Generate a poster first.';
      });
      return;
    }
    if (emailController.text.trim().isEmpty) {
      setState(() {
        emailSuccess = false;
        emailStatusMessage = 'Enter a recipient email address.';
      });
      return;
    }

    setState(() {
      sendingEmail = true;
      emailStatusMessage = null;
      emailSuccess = null;
    });

    try {
      final response = await PosterService.sendEmail({
        'recipient_emails': emailController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'subject': emailSubjectController.text.trim().isEmpty ? 'Your Marketing Promotion Poster' : emailSubjectController.text.trim(),
        'message': 'Please find the attached promotional poster.',
        'image_b64': posterImageB64,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          emailSuccess = true;
          emailStatusMessage = data['message'] ?? 'Email sent.';
          sendingEmail = false;
        });
      } else {
        final body = json.decode(response.body);
        setState(() {
          emailSuccess = false;
          emailStatusMessage = body['detail'] ?? 'Something went wrong (${response.statusCode})';
          sendingEmail = false;
        });
      }
    } catch (e) {
      setState(() {
        emailSuccess = false;
        emailStatusMessage = 'Could not reach the backend.\n\n$e';
        sendingEmail = false;
      });
    }
  }

  Future<void> pickScheduleDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: scheduledDate ?? DateTime.now().add(const Duration(days: 1)),
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
    if (picked != null) {
      setState(() => scheduledDate = picked);
    }
  }

  Future<void> schedulePoster() async {
    if (posterImageB64 == null) {
      setState(() {
        scheduleSuccess = false;
        scheduleStatusMessage = 'Generate a poster first.';
      });
      return;
    }
    if (emailController.text.trim().isEmpty) {
      setState(() {
        scheduleSuccess = false;
        scheduleStatusMessage = 'Enter a recipient email address.';
      });
      return;
    }
    if (scheduledDate == null) {
      setState(() {
        scheduleSuccess = false;
        scheduleStatusMessage = 'Pick a date first.';
      });
      return;
    }

    setState(() {
      scheduling = true;
      scheduleStatusMessage = null;
      scheduleSuccess = null;
    });

    try {
      final dateStr = '${scheduledDate!.year}-${scheduledDate!.month.toString().padLeft(2, '0')}-${scheduledDate!.day.toString().padLeft(2, '0')}';
      final response = await PosterService.schedulePoster({
        'poster_config': {
          'gender': gender,
          'age_group': ageGroup,
          'offer_type': offerType,
          'discount_value': discountValue,
          'season': season,
          'items': selectedItems.toList(),
          'palette': palette,
          'style': style,
          'brand_name': brandController.text,
          'tagline': taglineController.text,
          'inspiration': inspirationController.text,
          'event_date': eventDateController.text,
          'event_time': eventTimeController.text,
          'event_location': eventLocationController.text,
          'valid_until': validUntilController.text,
          'hosting_branch': hostingBranch == 'None' ? '' : hostingBranch,
          'include_terms': includeTerms,
        },
        'image_b64': posterImageB64,
        'recipient_emails': emailController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList(),
        'subject': emailSubjectController.text.trim().isEmpty ? 'Your Marketing Promotion Poster' : emailSubjectController.text.trim(),
        'message': 'Please find the attached promotional poster.',
        'scheduled_date': dateStr,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          scheduleSuccess = true;
          scheduleStatusMessage = data['message'] ?? 'Poster scheduled.';
          scheduling = false;
        });
      } else {
        final body = json.decode(response.body);
        setState(() {
          scheduleSuccess = false;
          scheduleStatusMessage = body['detail'] ?? 'Something went wrong (${response.statusCode})';
          scheduling = false;
        });
      }
    } catch (e) {
      setState(() {
        scheduleSuccess = false;
        scheduleStatusMessage = 'Could not reach the backend.\n\n$e';
        scheduling = false;
      });
    }
  }

  // ── Internal tabs: Generate / History / Scheduled ──────
  int posterTabIndex = 0;
  List<dynamic> generationHistory = [];
  bool loadingHistory = false;
  List<dynamic> scheduledPosts = [];
  bool loadingScheduled = false;
  Set<String> sendingScheduledIds = {};

  Future<void> fetchHistory() async {
    setState(() => loadingHistory = true);
    try {
      final response = await PosterService.fetchHistory();
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          generationHistory = data['history'] ?? [];
          loadingHistory = false;
        });
      } else {
        setState(() => loadingHistory = false);
      }
    } catch (e) {
      setState(() => loadingHistory = false);
    }
  }

  Future<void> fetchScheduled() async {
    setState(() => loadingScheduled = true);
    try {
      final response = await PosterService.fetchScheduled();
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          scheduledPosts = data['scheduled'] ?? [];
          loadingScheduled = false;
        });
      } else {
        setState(() => loadingScheduled = false);
      }
    } catch (e) {
      setState(() => loadingScheduled = false);
    }
  }

  Future<void> sendScheduledNow(String id) async {
    setState(() => sendingScheduledIds.add(id));
    try {
      final response = await PosterService.sendScheduledNow(id);
      if (response.statusCode == 200) {
        await fetchScheduled();
      }
    } catch (e) {
      // silently fail — status stays pending, user can retry
    }
    setState(() => sendingScheduledIds.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Poster Generator'),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.cardBackground,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _posterTabButton('Generate', 0),
                const SizedBox(width: 8),
                _posterTabButton('History', 1, onTap: fetchHistory),
                const SizedBox(width: 8),
                _posterTabButton('Scheduled', 2, onTap: fetchScheduled),
              ],
            ),
          ),
          Expanded(
            child: posterTabIndex == 0
                ? SingleChildScrollView(
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
                  )
                : posterTabIndex == 1
                    ? PosterHistoryTab(loading: loadingHistory, history: generationHistory)
                    : PosterScheduledTab(
                        loading: loadingScheduled,
                        scheduled: scheduledPosts,
                        sendingIds: sendingScheduledIds,
                        onSendNow: sendScheduledNow,
                      ),
          ),
        ],
      ),
    );
  }

  Widget _posterTabButton(String label, int index, {VoidCallback? onTap}) {
    final isSelected = posterTabIndex == index;
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          setState(() => posterTabIndex = index);
          if (onTap != null) onTap();
        },
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? AppColors.goldAccent.withValues(alpha: 0.15) : Colors.transparent,
          foregroundColor: isSelected ? AppColors.goldAccent : AppColors.textMuted,
          side: BorderSide(color: isSelected ? AppColors.goldAccent : AppColors.divider),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildForm() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Poster Generation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.infoBackground, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.goldAccent)),
            child: const Text(
              'Posters are generated automatically using Gemini — no setup needed. Just fill in the details below and hit Generate.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Customer Segment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _dropdown('Gender', gender, genders, (v) => setState(() => gender = v!)),
          _dropdown('Age Group', ageGroup, ageGroups, (v) => setState(() => ageGroup = v!)),

          const SizedBox(height: 12),
          const Text('Offer Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _dropdown('Offer Type', offerType, offerTypes, (v) => setState(() => offerType = v!)),
          _dropdown('Discount', discountValue, discountValues, (v) => setState(() => discountValue = v!)),
          _dropdown('Season / Campaign', season, seasons, (v) => setState(() => season = v!)),

          const SizedBox(height: 12),
          const Text('Items for Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: allItems.map((item) {
              final selected = selectedItems.contains(item);
              return FilterChip(
                label: Text(item, style: const TextStyle(fontSize: 12)),
                selected: selected,
                selectedColor: AppColors.goldAccent.withValues(alpha: 0.3),
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
          const Text('Visual Style', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _dropdown('Colour Palette', palette, palettes, (v) => setState(() => palette = v!)),
          _dropdown('Illustration Style', style, styles, (v) => setState(() => style = v!)),
          const SizedBox(height: 12),
          TextField(
            controller: brandController,
            decoration: const InputDecoration(labelText: 'Brand name', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: taglineController,
            decoration: const InputDecoration(
              labelText: 'Tagline / dates (optional)',
              hintText: 'e.g. "Valid 1–15 Sept" or "Don\'t Miss Out!"',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: inspirationController,
            decoration: const InputDecoration(
              labelText: 'Inspiration (optional)',
              hintText: 'e.g. "Spiderman" — a theme to inspire the visual style',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Event Details (optional — for in-store events/pop-ups)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: eventDateController,
                  decoration: const InputDecoration(labelText: 'Date', hintText: 'e.g. 15 Sept 2026', border: OutlineInputBorder(), isDense: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: eventTimeController,
                  decoration: const InputDecoration(labelText: 'Time', hintText: 'e.g. 6:00 PM - 9:00 PM', border: OutlineInputBorder(), isDense: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: eventLocationController,
            decoration: const InputDecoration(labelText: 'Location', hintText: 'e.g. Main Atrium, Colombo City Centre', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: validUntilController,
            decoration: const InputDecoration(labelText: 'Valid until', hintText: 'e.g. 30 Sept 2026', border: OutlineInputBorder(), isDense: true),
          ),
          const SizedBox(height: 10),
          _dropdown('Hosting branch (optional)', hostingBranch, hostingBranches, (v) => setState(() => hostingBranch = v!)),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Include "Terms and Conditions Applied"', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            value: includeTerms,
            onChanged: (v) => setState(() => includeTerms = v ?? false),
            activeColor: AppColors.goldAccent,
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: generating ? null : generatePoster,
              icon: generating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                  : const Icon(Icons.auto_awesome),
              label: Text(generating ? 'Generating... (30-90s)' : 'Generate Poster'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.cardBackground,
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              if (posterImageBytes != null)
                OutlinedButton.icon(
                  onPressed: downloadPoster,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.goldAccent,
                    side: const BorderSide(color: AppColors.goldAccent),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.errorBackground, borderRadius: BorderRadius.circular(8)),
              child: Text(errorMessage!, style: TextStyle(color: AppColors.errorText, fontSize: 13)),
            )
          else if (posterImageBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(posterImageBytes!, fit: BoxFit.contain),
            ),
            const SizedBox(height: 20),
            _buildEmailBar(),
          ] else
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.scaffoldBackground, borderRadius: BorderRadius.circular(8)),
              child: const Column(
                children: [
                  Icon(Icons.image_outlined, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text('Your generated poster will appear here', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmailBar() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Send this poster', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: emailSubjectController,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'recipient@email.com, another@email.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: sendingEmail ? null : sendPosterEmail,
                icon: sendingEmail
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                    : const Icon(Icons.send, size: 16),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          if (emailStatusMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  emailSuccess == true ? Icons.check_circle : Icons.error,
                  color: emailSuccess == true ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(emailStatusMessage!, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          const Text('Or schedule for later', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: pickScheduleDate,
                  icon: const Icon(Icons.calendar_today, size: 14),
                  label: Text(
                    scheduledDate == null
                        ? 'Pick a date'
                        : '${scheduledDate!.year}-${scheduledDate!.month.toString().padLeft(2, '0')}-${scheduledDate!.day.toString().padLeft(2, '0')}',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: scheduling ? null : schedulePoster,
                icon: scheduling
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                    : const Icon(Icons.schedule_send, size: 16),
                label: const Text('Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cardBackground,
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.goldAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ],
          ),
          if (scheduleStatusMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  scheduleSuccess == true ? Icons.check_circle : Icons.error,
                  color: scheduleSuccess == true ? Colors.green : Colors.red,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(scheduleStatusMessage!, style: const TextStyle(fontSize: 12))),
              ],
            ),
          ],
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
