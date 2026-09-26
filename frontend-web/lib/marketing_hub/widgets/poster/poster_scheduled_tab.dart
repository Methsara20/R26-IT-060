import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PosterScheduledTab extends StatelessWidget {
  final bool loading;
  final List<dynamic> scheduled;
  final Set<String> sendingIds;
  final void Function(String id) onSendNow;

  const PosterScheduledTab({
    super.key,
    required this.loading,
    required this.scheduled,
    required this.sendingIds,
    required this.onSendNow,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (scheduled.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No posters scheduled.', style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: scheduled.length,
      itemBuilder: (context, i) {
        final item = scheduled[i];
        final config = item['poster_config'] ?? {};
        final recipients = (item['recipient_emails'] as List?)?.join(', ') ?? '';
        final isSent = item['status'] == 'sent';
        final isSending = sendingIds.contains(item['id']);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSent ? AppColors.divider : AppColors.goldAccent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(isSent ? Icons.check_circle : Icons.schedule, size: 14, color: isSent ? Colors.green : AppColors.goldAccent),
                        const SizedBox(width: 6),
                        Text(
                          item['scheduled_date'] ?? '-',
                          style: TextStyle(fontWeight: FontWeight.bold, color: isSent ? AppColors.textMuted : AppColors.goldAccent, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${config['offer_type'] ?? '-'} — ${config['season'] ?? '-'}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text('To: $recipients', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (!isSent)
                ElevatedButton(
                  onPressed: isSending ? null : () => onSendNow(item['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.scaffoldBackground,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.goldAccent),
                  ),
                  child: isSending
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textPrimary))
                      : const Text('Send Now', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}
