import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../models/period_settings.dart';
import '../../services/period_service.dart';
import '../../services/period_cycle_utils.dart';
import '../screens/period_tracker/period_tracker_screen.dart';

/// Home-dashboard status card: shows whether the couple is currently in
/// a period, ovulating, in the fertile window, or counting down to the
/// next predicted period — plus a small "how to treat your partner right
/// now" cue. Renders nothing until at least one period has been logged.
class PeriodCountdownCard extends StatelessWidget {
  final String coupleId;
  const PeriodCountdownCard({super.key, required this.coupleId});

  DateTime _utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final periodService = PeriodService();

    return StreamBuilder<List<PeriodEntry>>(
      stream: periodService.watchEntries(coupleId),
      builder: (context, entriesSnap) {
        if (!entriesSnap.hasData) return const SizedBox.shrink();
        final entries = entriesSnap.data!;
        if (entries.isEmpty) return const SizedBox.shrink();

        return StreamBuilder<PeriodSettings>(
          stream: periodService.watchSettings(coupleId),
          builder: (context, settingsSnap) {
            final settings =
                settingsSnap.data ??
                const PeriodSettings(avgCycleLength: 28, avgPeriodLength: 5);

            final status = _computeStatus(entries, settings);

            return Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PeriodTrackerScreen(coupleId: coupleId),
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
                            status.icon,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            status.headline,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      RichText(
                        text: TextSpan(
                          style: DefaultTextStyle.of(
                            context,
                          ).style.copyWith(fontSize: 13),
                          children: [
                            TextSpan(
                              text: status.subline,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            const TextSpan(text: ' · '),
                            TextSpan(text: status.tip),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      CycleInfoBlock(
                        cycleDay: status.cycleDay,
                        phaseName: status.phaseName,
                        conceptionChance: status.conceptionChance,
                        cervicalMucus: status.cervicalMucus,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  _PeriodStatus _computeStatus(
    List<PeriodEntry> entries,
    PeriodSettings settings,
  ) {
    final today = _utc(DateTime.now());
    final periodLen = settings.avgPeriodLength;
    final cycleLen = settings.avgCycleLength;

    // Ovulation is modeled as 14 days before the next period starts —
    // both expressed as a 1-based day-of-cycle, since cycleStart is day 1.
    final ovulationCycleDay = cycleLen - 13;
    final fertileStartDay = ovulationCycleDay - 5;

    // 1. Currently on a period.
    final ongoing = entries.where((e) => e.isOngoing).toList();
    if (ongoing.isNotEmpty) {
      final start = _utc(DateTime.parse(ongoing.first.startDate));
      final day = today.difference(start).inDays + 1;
      return _PeriodStatus(
        icon: Icons.water_drop,
        color: Colors.red.shade300,
        headline: 'Day $day of period',
        subline: 'Started ${DateFormat.MMMd().format(start)}',
        tip: _periodTip(day),
        cycleDay: day,
        phaseName: 'Menstruation',
        conceptionChance: ConceptionChance.low,
        cervicalMucus:
            'Little to no noticeable cervical mucus because it\'s masked by menstrual flow.',
      );
    }

    final projection = PeriodCycleUtils.projectFor(today, entries, cycleLen)!;
    final ovulationDay = projection.ovulationDay;
    final fertileStart = projection.fertileStart;
    final fertileEnd = projection.fertileEnd;
    final nextPeriodStart = projection.nextPeriodStart;

    final cycleDay = projection.cycleDay;
    final phaseName = PeriodCycleUtils.phaseNameFor(
      cycleDay,
      periodLen,
      ovulationCycleDay,
    );
    final conceptionChance = PeriodCycleUtils.conceptionChanceFor(
      cycleDay,
      fertileStartDay,
      ovulationCycleDay,
    );
    final cervicalMucus = PeriodCycleUtils.cervicalMucusFor(
      cycleDay,
      periodLen,
      fertileStartDay,
      ovulationCycleDay,
    );

    // 2. Ovulation day.
    if (today.isAtSameMomentAs(ovulationDay)) {
      return _PeriodStatus(
        icon: Icons.local_florist,
        color: Colors.teal.shade300,
        headline: 'Ovulation day',
        subline: 'Peak fertility today',
        tip:
            "She might feel extra energetic today — a good day for a spontaneous date 🌷",
        cycleDay: cycleDay,
        phaseName: phaseName,
        conceptionChance: conceptionChance,
        cervicalMucus: cervicalMucus,
      );
    }

    // 3. Fertile window (5 days before ovulation through 1 day after).
    if (!today.isBefore(fertileStart) && !today.isAfter(fertileEnd)) {
      final beforeOvulation = today.isBefore(ovulationDay);
      final daysToOvulation = ovulationDay.difference(today).inDays;
      return _PeriodStatus(
        icon: Icons.spa_outlined,
        color: Colors.teal.shade200,
        headline: 'Fertile window',
        subline: beforeOvulation
            ? 'Ovulation in $daysToOvulation day${daysToOvulation == 1 ? '' : 's'}'
            : 'Ovulation was yesterday',
        tip:
            'Good days to be extra thoughtful — and worth a chat if you\'re planning ahead 💬',
        cycleDay: cycleDay,
        phaseName: phaseName,
        conceptionChance: conceptionChance,
        cervicalMucus: cervicalMucus,
      );
    }

    // 4. Countdown to next predicted period.
    final daysUntil = nextPeriodStart.difference(today).inDays;
    return _PeriodStatus(
      icon: Icons.event_outlined,
      color: Colors.pink.shade200,
      headline: daysUntil <= 0
          ? 'Period may start today'
          : 'Next period in $daysUntil day${daysUntil == 1 ? '' : 's'}',
      subline: 'Around ${DateFormat.MMMMd().format(nextPeriodStart)}',
      tip: daysUntil <= 3
          ? 'Might be a good time for chocolate, a warm meal, or just extra patience 🍫'
          : "Just a heads up so you're not caught off guard later 🩷",
      cycleDay: cycleDay,
      phaseName: phaseName,
      conceptionChance: conceptionChance,
      cervicalMucus: cervicalMucus,
    );
  }

  String _periodTip(int day) {
    if (day <= 2) {
      return 'Cramps hit hardest early on — a heating pad and a little extra gentleness go a long way 🫂';
    }
    return "Still worth checking in — snacks, comfort, and no unnecessary pressure today 🍵";
  }
}

class _PeriodStatus {
  final IconData icon;
  final Color color;
  final String headline;
  final String subline;
  final String tip;
  final int cycleDay;
  final String phaseName;
  final ConceptionChance conceptionChance;
  final String cervicalMucus;

  const _PeriodStatus({
    required this.icon,
    required this.color,
    required this.headline,
    required this.subline,
    required this.tip,
    required this.cycleDay,
    required this.phaseName,
    required this.conceptionChance,
    required this.cervicalMucus,
  });
}
