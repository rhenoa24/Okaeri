import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/plan.dart';
import '../../services/calendar_service.dart';
import 'plan_editor_screen.dart';

String _dayLabel(String dateStr, DateTime now) {
  final parts = dateStr.split('-').map(int.parse).toList();
  final d = DateTime(parts[0], parts[1], parts[2]);
  final today = DateTime(now.year, now.month, now.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  return DateFormat('MMMM d • EEEE, yyyy').format(d);
}

String _displayTime(String time) {
  final hour = int.parse(time.split(':')[0]);
  final minute = time.split(':')[1];
  final period = hour >= 12 ? 'PM' : 'AM';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$minute $period';
}

class PlansScreen extends StatefulWidget {
  final String coupleId;
  const PlansScreen({super.key, required this.coupleId});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plans'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm, size: 18),
                  SizedBox(width: 6),
                  Text('Upcoming Plans'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 18),
                  SizedBox(width: 6),
                  Text('Past Logs'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PlansListTab(
            coupleId: widget.coupleId,
            now: now,
            upcomingOnly: true,
          ),
          _PlansListTab(
            coupleId: widget.coupleId,
            now: now,
            upcomingOnly: false,
          ),
        ],
      ),
    );
  }
}

class _PlansListTab extends StatelessWidget {
  final String coupleId;
  final DateTime now;
  final bool upcomingOnly;

  const _PlansListTab({
    required this.coupleId,
    required this.now,
    required this.upcomingOnly,
  });

  @override
  Widget build(BuildContext context) {
    final calendarService = CalendarService();

    return StreamBuilder<List<Plan>>(
      stream: calendarService.watchPlans(coupleId, limit: 100),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final plans = snapshot.data!;
        if (plans.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No plans yet.\nTap + to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          );
        }

        final today = DateTime(now.year, now.month, now.day);
        final filtered = plans.where((plan) {
          final itemDate = plan.parsedDate;
          return upcomingOnly
              ? !itemDate.isBefore(today)
              : itemDate.isBefore(today);
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                upcomingOnly ? 'No upcoming plans yet.' : 'No past plans yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
          );
        }

        // Group plans by date so multiple plans on the same day still get
        // a shared day header — but each plan keeps its own card, title,
        // and timetable, instead of every timestamp being flattened together.
        final grouped = <String, List<Plan>>{};
        for (final plan in filtered) {
          grouped.putIfAbsent(plan.date, () => []).add(plan);
        }
        final sortedDates = grouped.keys.toList()
          ..sort((a, b) => upcomingOnly ? a.compareTo(b) : b.compareTo(a));

        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          children: sortedDates.map((date) {
            final dayPlans = grouped[date]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayLabel(date, now),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...dayPlans.map(
                    (plan) => _PlanCard(coupleId: coupleId, plan: plan),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String coupleId;
  final Plan plan;

  const _PlanCard({required this.coupleId, required this.plan});

  @override
  Widget build(BuildContext context) {
    final entries = plan.sortedTimetable;
    const previewCount = 3;
    final preview = entries.take(previewCount).toList();
    final remaining = entries.length - preview.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PlanEditorScreen(
                coupleId: coupleId,
                initialDate: plan.parsedDate,
                existingPlan: plan,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                if (preview.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'No timetable yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 13,
                      ),
                    ),
                  )
                else ...[
                  const SizedBox(height: 10),
                  ...preview.map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 76,
                            child: Text(
                              _displayTime(e.time),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.outline,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.text,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (remaining > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+$remaining more',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
