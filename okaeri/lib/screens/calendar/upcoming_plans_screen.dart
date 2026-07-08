import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/schedule_item.dart';
import '../../services/calendar_service.dart';

String _dayLabel(String dateStr, DateTime now) {
  final parts = dateStr.split('-').map(int.parse).toList();
  final d = DateTime(parts[0], parts[1], parts[2]);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return DateFormat('EEEE, MMMM d').format(d);
}

String _displayTime(String time) {
  final hour = int.parse(time.split(':')[0]);
  final minute = time.split(':')[1];
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$minute $period';
}

class UpcomingPlansScreen extends StatelessWidget {
  final String coupleId;
  const UpcomingPlansScreen({super.key, required this.coupleId});

  @override
  Widget build(BuildContext context) {
    final calendarService = CalendarService();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Upcoming Plans')),
      body: StreamBuilder<List<ScheduleItem>>(
        stream: calendarService.watchUpcomingSchedule(coupleId, limit: 50),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No upcoming plans yet.\nAdd one from the Calendar tab.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          // Group items by date, preserving the already-sorted order
          final grouped = <String, List<ScheduleItem>>{};
          for (final item in items) {
            grouped.putIfAbsent(item.date, () => []).add(item);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: grouped.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dayLabel(entry.key, now),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Column(
                          children: entry.value
                              .map(
                                (item) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          _displayTime(item.time),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Text(item.text)),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
