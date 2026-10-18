import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PosterHistoryTab extends StatelessWidget {
  final bool loading;
  final List<dynamic> history;

  const PosterHistoryTab({super.key, required this.loading, required this.history});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No posters generated yet.', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final item = history[i];
        final items = (item['items'] as List?)?.join(', ') ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['offer_type'] ?? '-'} — ${item['season'] ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '${item['gender'] ?? '-'}, ${item['age_group'] ?? '-'} · $items',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
              if (item['generated_at'] != null) ...[
                const SizedBox(height: 4),
                Text(item['generated_at'], style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
              ],
            ],
          ),
        );
      },
    );
  }
}
