import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/calendar_service.dart';
import '../core/widgets/glass_card.dart';

// ── Promotion Calendar Screen ─────────────────────────────────
class PromotionCalendarScreen extends StatefulWidget {
  const PromotionCalendarScreen({super.key});

  @override
  State<PromotionCalendarScreen> createState() => _PromotionCalendarScreenState();
}

class _PromotionCalendarScreenState extends State<PromotionCalendarScreen> {
  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const monthAbbrev = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  // Note category -> color mapping
  static const Map<String, Color> categoryColors = {
    'Reminder': AppColors.blueAccent,
    'Campaign Idea': AppColors.goldAccent,
    'Urgent': AppColors.urgentAccent,
    'General': AppColors.neutralGrey,
  };

  // Sri Lanka public holidays 2026 — sourced from the Government Printing
  // Department's official 2026 calendar (26 public holidays).
  static const Map<String, String> sriLankaHolidays2026 = {
    '2026-01-01': "New Year's Day",
    '2026-01-03': 'Duruthu Full Moon Poya Day',
    '2026-01-15': 'Tamil Thai Pongal Day',
    '2026-02-01': 'Navam Full Moon Poya Day',
    '2026-02-04': 'Independence Day',
    '2026-02-15': 'Maha Shivaratri Day',
    '2026-03-02': 'Medin Full Moon Poya Day',
    '2026-03-21': 'Eid-ul-Fitr',
    '2026-04-01': 'Bak Full Moon Poya Day',
    '2026-04-03': 'Good Friday',
    '2026-04-13': 'Day before Sinhala & Tamil New Year',
    '2026-04-14': 'Sinhala and Tamil New Year Day',
    '2026-05-01': 'Vesak Poya Day / May Day',
    '2026-05-02': 'Day after Vesak Full Moon Poya Day',
    '2026-05-28': 'Eid al-Adha',
    '2026-05-30': 'Adhi Poson Full Moon Poya Day',
    '2026-06-29': 'Poson Full Moon Poya Day',
    '2026-07-29': 'Esala Full Moon Poya Day',
    '2026-08-26': 'Milad-un-Nabi',
    '2026-08-27': 'Nikini Full Moon Poya Day',
    '2026-09-26': 'Binara Full Moon Poya Day',
    '2026-10-25': 'Vap Full Moon Poya Day',
    '2026-11-08': 'Deepavali Festival Day',
    '2026-11-24': 'Ill Full Moon Poya Day',
    '2026-12-23': 'Unduvap Full Moon Poya Day',
    '2026-12-25': 'Christmas Day',
  };

  static const List<Map<String, dynamic>> seasonalWindows = [
    {'startMonth': 3, 'startDay': 1, 'endMonth': 4, 'endDay': 30, 'label': 'New Year Season', 'color': AppColors.goldAccent},
    {'startMonth': 6, 'startDay': 1, 'endMonth': 7, 'endDay': 31, 'label': 'Mid-Year Promotions', 'color': AppColors.blueAccent},
    {'startMonth': 11, 'startDay': 1, 'endMonth': 11, 'endDay': 30, 'label': 'Black Friday', 'color': AppColors.urgentAccent},
    {'startMonth': 12, 'startDay': 1, 'endMonth': 12, 'endDay': 31, 'label': 'Christmas & New Year', 'color': AppColors.greenAccent},
  ];

  DateTime displayedMonth = DateTime(2026, DateTime.now().month);
  bool showYearView = false;
  int yearViewYear = 2026;

  Map<int, int> campaignCounts = {};
  List<dynamic> notes = [];
  bool loading = true;

  Map<String, dynamic> yearCampaignCounts = {}; // {month: {day: count}}
  List<dynamic> yearNotes = [];
  bool loadingYear = false;

  final noteController = TextEditingController();
  String selectedCategory = 'General';

  @override
  void initState() {
    super.initState();
    fetchMonthData();
  }

  Future<void> fetchMonthData() async {
    setState(() => loading = true);
    try {
      final year = displayedMonth.year;
      final month = displayedMonth.month;

      final campaignResp = await CalendarService.fetchCampaigns(year: year, month: month);
      final notesResp = await CalendarService.fetchNotes(year: year, month: month);

      Map<int, int> counts = {};
      if (campaignResp.statusCode == 200) {
        final data = json.decode(campaignResp.body) as Map<String, dynamic>;
        data.forEach((k, v) => counts[int.parse(k)] = v as int);
      }

      List<dynamic> loadedNotes = [];
      if (notesResp.statusCode == 200) {
        loadedNotes = json.decode(notesResp.body);
      }

      if (!mounted) return;
      setState(() {
        campaignCounts = counts;
        notes = loadedNotes;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> fetchYearData() async {
    setState(() => loadingYear = true);
    try {
      final campaignResp = await CalendarService.fetchCampaignsForYear(yearViewYear);
      final notesResp = await CalendarService.fetchNotesForYear(yearViewYear);

      Map<String, dynamic> counts = {};
      if (campaignResp.statusCode == 200) {
        counts = json.decode(campaignResp.body) as Map<String, dynamic>;
      }

      List<dynamic> loadedNotes = [];
      if (notesResp.statusCode == 200) {
        loadedNotes = json.decode(notesResp.body);
      }

      if (!mounted) return;
      setState(() {
        yearCampaignCounts = counts;
        yearNotes = loadedNotes;
        loadingYear = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loadingYear = false);
    }
  }

  void toggleYearView() {
    setState(() => showYearView = !showYearView);
    if (showYearView && yearCampaignCounts.isEmpty && yearNotes.isEmpty) {
      fetchYearData();
    }
  }

  void changeMonth(int delta) {
    setState(() {
      displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + delta);
    });
    fetchMonthData();
  }

  void changeYear(int delta) {
    setState(() => yearViewYear += delta);
    fetchYearData();
  }

  String _dateKey(int day) {
    final y = displayedMonth.year;
    final m = displayedMonth.month;
    return '$y-${m.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  List<dynamic> _notesForDay(int day) {
    final key = _dateKey(day);
    return notes.where((n) => n['date'] == key).toList();
  }

  Color? _dominantNoteColor(int day) {
    final dayNotes = _notesForDay(day);
    if (dayNotes.isEmpty) return null;
    const priority = ['Urgent', 'Campaign Idea', 'Reminder', 'General'];
    for (final cat in priority) {
      if (dayNotes.any((n) => (n['category'] ?? 'General') == cat)) {
        return categoryColors[cat];
      }
    }
    return categoryColors['General'];
  }

  bool _isInSeasonalWindow(int day) {
    final m = displayedMonth.month;
    for (final win in seasonalWindows) {
      final sm = win['startMonth'] as int, sd = win['startDay'] as int;
      final em = win['endMonth'] as int, ed = win['endDay'] as int;
      if (sm <= em) {
        if (m > sm && m < em) return true;
        if (m == sm && m == em) return day >= sd && day <= ed;
        if (m == sm) return day >= sd;
        if (m == em) return day <= ed;
      }
    }
    return false;
  }

  Future<void> addNote(int day) async {
    if (noteController.text.trim().isEmpty) return;
    final key = _dateKey(day);
    try {
      await CalendarService.addNote(date: key, text: noteController.text.trim(), category: selectedCategory);
      noteController.clear();
      selectedCategory = 'General';
      await fetchMonthData();
    } catch (e) {
      // silently fail — note just won't persist, non-critical
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await CalendarService.deleteNote(noteId);
      await fetchMonthData();
    } catch (e) {
      // Deletion is non-critical; the next refresh will retain the existing note.
    }
  }

  void openDayDialog(int day) {
    final key = _dateKey(day);
    final holiday = sriLankaHolidays2026[key];
    final dayNotes = _notesForDay(day);
    selectedCategory = 'General';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${monthNames[displayedMonth.month - 1]} $day, ${displayedMonth.year}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (holiday != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: AppColors.infoBackground, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.celebration, size: 16, color: AppColors.goldAccent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(holiday, style: const TextStyle(fontSize: 13))),
                      ]),
                    ),
                  if (campaignCounts[day] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('📣 ${campaignCounts[day]} campaigns sent this day', style: const TextStyle(fontSize: 13)),
                    ),
                  const Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...dayNotes.map((n) {
                    final cat = n['category'] ?? 'General';
                    final color = categoryColors[cat] ?? AppColors.textMuted;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                      title: Text(n['text'], style: const TextStyle(fontSize: 13)),
                      subtitle: Text(cat, style: TextStyle(fontSize: 11, color: color)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () async {
                          await deleteNote(n['id']);
                           if (!context.mounted) return;
                           setDialogState(() {});
                          Navigator.pop(context);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(hintText: 'Add a note...', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 10),
                  const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: categoryColors.keys.map((cat) {
                      final isSelected = selectedCategory == cat;
                      final color = categoryColors[cat]!;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(fontSize: 11, color: isSelected ? AppColors.cardBackground : color)),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withValues(alpha: 0.12),
                        onSelected: (_) => setDialogState(() => selectedCategory = cat),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ElevatedButton(
              onPressed: () async {
                await addNote(day);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text('Add Note'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Promotion Calendar'),
        actions: [
          IconButton(
            icon: Icon(showYearView ? Icons.calendar_view_month : Icons.calendar_view_day),
            tooltip: showYearView ? 'Month view' : 'Year view',
            onPressed: toggleYearView,
          ),
        ],
      ),
      body: showYearView ? _buildYearView() : _buildMonthView(),
    );
  }

  // ── Month view ───────────────────────────────────────────────
  Widget _buildMonthView() {
    final firstDayOfMonth = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Monday

    List<int?> cells = List.filled(startWeekday - 1, null, growable: true);
    cells.addAll(List.generate(daysInMonth, (i) => i + 1));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => changeMonth(-1)),
              Text('${monthNames[displayedMonth.month - 1]} ${displayedMonth.year}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => changeMonth(1)),
              const Spacer(),
              if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _legendChip('Seasonal Window', AppColors.goldAccent),
            _legendChip('Holiday 🎉', AppColors.holidayHighlight),
            ...categoryColors.entries.map((e) => _legendChip(e.key, e.value)),
          ]),
          const SizedBox(height: 16),
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted)))))
                .toList(),
          ),
          const SizedBox(height: 4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.42),
            itemCount: cells.length,
            itemBuilder: (context, index) {
              final day = cells[index];
              if (day == null) return const SizedBox();

              final key = _dateKey(day);
              final isHoliday = sriLankaHolidays2026.containsKey(key);
              final isSeasonal = _isInSeasonalWindow(day);
              final dayNotes = _notesForDay(day);
              final campCount = campaignCounts[day];
              final noteColor = _dominantNoteColor(day);

              Color topColor = const Color(0x1AFFFFFF); // 10% white
              Color bottomColor = const Color(0x05FFFFFF); // 2% white
              
              if (isHoliday) {
                topColor = AppColors.holidayHighlight.withValues(alpha: 0.25);
                bottomColor = AppColors.holidayHighlight.withValues(alpha: 0.05);
              } else if (isSeasonal) {
                topColor = AppColors.goldAccent.withValues(alpha: 0.2);
                bottomColor = AppColors.goldAccent.withValues(alpha: 0.05);
              }
              if (noteColor != null) {
                topColor = noteColor.withValues(alpha: 0.2);
                bottomColor = noteColor.withValues(alpha: 0.05);
              }

              final visibleNotes = dayNotes;

              return GestureDetector(
                onTap: () => openDayDialog(day),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [topColor, bottomColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: noteColor != null ? noteColor.withValues(alpha: 0.6) : AppColors.divider.withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
                          if (campCount != null)
                            Text('📣$campCount', style: const TextStyle(fontSize: 9)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      ...visibleNotes.map((n) {
                        final cat = n['category'] ?? 'General';
                        final color = categoryColors[cat] ?? AppColors.textMuted;
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                          child: Text(
                            n['text'],
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('Tap any day to view holiday info, campaign activity, or add a note.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ── Year heatmap view ────────────────────────────────────────
  Widget _buildYearView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => changeYear(-1)),
              Text('$yearViewYear Activity Overview', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => changeYear(1)),
              const Spacer(),
              if (loadingYear) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Darker cells indicate more campaigns and notes on that day.', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          ...List.generate(12, (monthIdx) => _buildMonthHeatmapRow(monthIdx + 1)),
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Less', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(width: 6),
              ...List.generate(5, (i) => Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: AppColors.goldAccent.withValues(alpha: 0.15 + i * 0.2), borderRadius: BorderRadius.circular(3)),
                  )),
              const SizedBox(width: 6),
              const Text('More', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthHeatmapRow(int month) {
    final daysInMonth = DateTime(yearViewYear, month + 1, 0).day;
    final monthCampaigns = Map<String, dynamic>.from(yearCampaignCounts[month.toString()] ?? {});

    final monthPrefix = '$yearViewYear-${month.toString().padLeft(2, '0')}-';
    Map<int, int> noteCountByDay = {};
    for (final n in yearNotes) {
      final date = n['date'] as String? ?? '';
      if (date.startsWith(monthPrefix)) {
        final day = int.tryParse(date.substring(monthPrefix.length));
        if (day != null) noteCountByDay[day] = (noteCountByDay[day] ?? 0) + 1;
      }
    }

    int maxActivity = 1;
    for (int d = 1; d <= daysInMonth; d++) {
      final camp = (monthCampaigns[d.toString()] as num?)?.toInt() ?? 0;
      final note = noteCountByDay[d] ?? 0;
      final total = camp + note;
      if (total > maxActivity) maxActivity = total;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 36, child: Text(monthAbbrev[month - 1], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
          Expanded(
            child: Wrap(
              spacing: 3,
              runSpacing: 3,
              children: List.generate(daysInMonth, (i) {
                final day = i + 1;
                final camp = (monthCampaigns[day.toString()] as num?)?.toInt() ?? 0;
                final note = noteCountByDay[day] ?? 0;
                final total = camp + note;
                final intensity = total == 0 ? 0.06 : (0.2 + (total / maxActivity) * 0.8).clamp(0.2, 1.0);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      displayedMonth = DateTime(yearViewYear, month);
                      showYearView = false;
                    });
                    fetchMonthData();
                  },
                  child: Tooltip(
                    message: '${monthAbbrev[month - 1]} $day: $camp campaigns, $note notes',
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.goldAccent.withValues(alpha: intensity),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}
