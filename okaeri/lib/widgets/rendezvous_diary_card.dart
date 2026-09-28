import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/calendar_note.dart';
import '../services/calendar_service.dart';
import '../screens/calendar/rendezvous_diary_screen.dart';

/// Home-dashboard summary of the Rendezvous Diary: when the last entry was,
/// plus running totals for each marker. Tapping opens the full diary.
class RendezvousDiaryCard extends StatelessWidget {
  final String coupleId;
  const RendezvousDiaryCard({super.key, required this.coupleId});

  String _sinceLabel(DateTime last, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(DateTime(last.year, last.month, last.day)).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return '$diff days ago';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return StreamBuilder<List<CalendarNote>>(
      stream: CalendarService().watchAllNotes(coupleId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final stats = computeRendezvousStats(snapshot.data!, now);
        final last = stats.lastDate;

        return Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RendezvousDiaryScreen(coupleId: coupleId),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_stories_outlined,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Rendezvous Diary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, color: colors.outlineVariant),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (last == null)
                    Text(
                      'No entries yet. Add ❤️‍🔥 or ❣️ to an event to start your diary.',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: colors.outline,
                      ),
                    )
                  else
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(
                          context,
                        ).style.copyWith(fontSize: 13),
                        children: [
                          const TextSpan(text: 'Last rendezvous was on '),
                          TextSpan(
                            text: DateFormat.yMMMMd().format(last),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ' · ${_sinceLabel(last, now)}',
                            style: TextStyle(color: colors.outline),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(fontSize: 13, color: colors.outline),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${stats.fireHearts} ❤️‍🔥',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${stats.heartExclamations} ❣️',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}