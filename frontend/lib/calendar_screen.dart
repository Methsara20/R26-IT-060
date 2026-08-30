import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'core/constants/api_constants.dart';

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
    {'startMonth': 3, 'startDay': 1, 'endMonth': 4, 'endDay': 30, 'label': 'New Year Season', 'color': Color(0xFFD4A853)},
    {'startMonth': 6, 'startDay': 1, 'endMonth': 7, 'endDay': 31, 'label': 'Mid-Year Promotions', 'color': Color(0xFF7AA6C2)},
    {'startMonth': 11, 'startDay': 1, 'endMonth': 11, 'endDay': 30, 'label': 'Black Friday', 'color': Color(0xFFB4543A)},
    {'startMonth': 12, 'startDay': 1, 'endMonth': 12, 'endDay': 31, 'label': 'Christmas & New Year', 'color': Color(0xFF4A7C59)},
  ];

  DateTime displayedMonth = DateTime(2026, DateTime.now().month);

  Map<int, int> campaignCounts = {};
  List<dynamic> notes = [];
  bool loading = true;

  final noteController = TextEditingController();

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

      final campaignResp = await http
          .get(Uri.parse('$backendUrl/calendar/campaigns?year=$year&month=$month'))
          .timeout(const Duration(seconds: 10));
      final notesResp = await http
          .get(Uri.parse('$backendUrl/calendar/notes?year=$year&month=$month'))
          .timeout(const Duration(seconds: 10));

      Map<int, int> counts = {};
      if (campaignResp.statusCode == 200) {
        final data = json.decode(campaignResp.body) as Map<String, dynamic>;
        data.forEach((k, v) => counts[int.parse(k)] = v as int);
      }

      List<dynamic> loadedNotes = [];
      if (notesResp.statusCode == 200) {
        loadedNotes = json.decode(notesResp.body);
      }

      setState(() {
        campaignCounts = counts;
        notes = loadedNotes;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  void changeMonth(int delta) {
    setState(() {
      displayedMonth = DateTime(displayedMonth.year, displayedMonth.month + delta);
    });
    fetchMonthData();
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
      await http.post(
        Uri.parse('$backendUrl/calendar/notes'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'date': key, 'text': noteController.text.trim()}),
      );
      noteController.clear();
      await fetchMonthData();
    } catch (e) {
      // silently fail — note just won't persist, non-critical
    }
  }

  Future<void> deleteNote(String noteId) async {
    try {
      await http.delete(Uri.parse('$backendUrl/calendar/notes/$noteId'));
      await fetchMonthData();
    } catch (e) {
      // Silently fail because calendar notes are non-critical.
    }
  }

  void openDayDialog(int day) {
    final key = _dateKey(day);
    final holiday = sriLankaHolidays2026[key];
    final dayNotes = _notesForDay(day);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${monthNames[displayedMonth.month - 1]} $day, ${displayedMonth.year}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (holiday != null)
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8E7), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.celebration, size: 16, color: Color(0xFFD4A853)),
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
                ...dayNotes.map((n) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(n['text'], style: const TextStyle(fontSize: 13)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () async {
                          await deleteNote(n['id']);
                          if (!context.mounted) return;
                          setDialogState(() {});
                          Navigator.pop(context);
                        },
                      ),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(hintText: 'Add a note...', border: OutlineInputBorder(), isDense: true),
                ),
              ],
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
    final firstDayOfMonth = DateTime(displayedMonth.year, displayedMonth.month, 1);
    final daysInMonth = DateTime(displayedMonth.year, displayedMonth.month + 1, 0).day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Monday

    List<int?> cells = List.filled(startWeekday - 1, null, growable: true);
    cells.addAll(List.generate(daysInMonth, (i) => i + 1));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2744),
        foregroundColor: Colors.white,
        title: const Text('Promotion Calendar'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => changeMonth(-1)),
                Text('${monthNames[displayedMonth.month - 1]} ${displayedMonth.year}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2744))),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => changeMonth(1)),
                const Spacer(),
                if (loading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _legendChip('Seasonal Window', const Color(0xFFD4A853)),
              _legendChip('Holiday 🎉', const Color(0xFFE8D5A8)),
              _legendChip('Has Notes 📝', Colors.blue.shade100),
            ]),
            const SizedBox(height: 16),
            Row(
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6B5B3E))))))
                  .toList(),
            ),
            const SizedBox(height: 4),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.9),
              itemCount: cells.length,
              itemBuilder: (context, index) {
                final day = cells[index];
                if (day == null) return const SizedBox();

                final key = _dateKey(day);
                final isHoliday = sriLankaHolidays2026.containsKey(key);
                final isSeasonal = _isInSeasonalWindow(day);
                final dayNotes = _notesForDay(day);
                final campCount = campaignCounts[day];

                Color bg = Colors.white;
                if (isHoliday) {
                  bg = const Color(0xFFE8D5A8);
                } else if (isSeasonal) {
                  bg = const Color(0xFFD4A853).withValues(alpha: 0.15);
                }

                return GestureDetector(
                  onTap: () => openDayDialog(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEDE5D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$day', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1A2744))),
                        if (campCount != null)
                          Text('📣$campCount', style: const TextStyle(fontSize: 9)),
                        if (dayNotes.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4)),
                            child: Text('📝${dayNotes.length}', style: const TextStyle(fontSize: 8)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Tap any day to view holiday info, campaign activity, or add a note.',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
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
