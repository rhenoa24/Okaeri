import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../models/period_settings.dart';
import '../../services/period_service.dart';
import '../screens/calendar/period_tracker_screen.dart';

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
                      Text(
                        status.subline,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        status.tip,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Text(
                        'Cycle Day ${status.cycleDay} · ${status.phaseName} Phase',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Chance of Conception: ',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            status.conceptionChance.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: status.conceptionChance.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.cervicalMucus,
                        style: const TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
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
        conceptionChance: _ConceptionChance.low,
        cervicalMucus:
            'Bleeding — mucus observation isn\'t reliable right now.',
      );
    }

    final sorted = [...entries]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final anchor = _utc(DateTime.parse(sorted.last.startDate));

    final diffDays = today.difference(anchor).inDays;
    final cycleIndex = diffDays >= 0
        ? (diffDays / cycleLen).floor()
        : ((diffDays - cycleLen + 1) / cycleLen).floor();
    final cycleStart = anchor.add(Duration(days: cycleIndex * cycleLen));
    final ovulationDay = cycleStart.add(Duration(days: cycleLen - 14));
    final fertileStart = ovulationDay.subtract(const Duration(days: 5));
    final nextPeriodStart = cycleStart.add(Duration(days: cycleLen));

    final cycleDay = today.difference(cycleStart).inDays + 1;
    final phaseName = _phaseNameFor(cycleDay, periodLen, ovulationCycleDay);
    final conceptionChance = _conceptionChanceFor(
      cycleDay,
      fertileStartDay,
      ovulationCycleDay,
    );
    final cervicalMucus = _cervicalMucusFor(
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

    // 3. Fertile window.
    if (!today.isBefore(fertileStart) && today.isBefore(ovulationDay)) {
      final daysToOvulation = ovulationDay.difference(today).inDays;
      return _PeriodStatus(
        icon: Icons.spa,
        color: Colors.teal.shade200,
        headline: 'Fertile window',
        subline:
            'Ovulation in $daysToOvulation day${daysToOvulation == 1 ? '' : 's'}',
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
      icon: Icons.event,
      color: Colors.pink.shade200,
      headline: daysUntil <= 0
          ? 'Period may start today'
          : 'Next period in $daysUntil day${daysUntil == 1 ? '' : 's'}',
      subline: 'Around ${DateFormat.MMMd().format(nextPeriodStart)}',
      tip: daysUntil <= 3
          ? 'Might be a good time for chocolate, a warm meal, or just extra patience 🍫'
          : "Just a heads up so you're not caught off guard later 🩷",
      cycleDay: cycleDay,
      phaseName: phaseName,
      conceptionChance: conceptionChance,
      cervicalMucus: cervicalMucus,
    );
  }

  String _phaseNameFor(int cycleDay, int periodLen, int ovulationCycleDay) {
    if (cycleDay <= periodLen) return 'Menstruation';
    if (cycleDay < ovulationCycleDay) return 'Follicular';
    if (cycleDay == ovulationCycleDay) return 'Ovulation';
    return 'Luteal';
  }

  _ConceptionChance _conceptionChanceFor(
    int cycleDay,
    int fertileStartDay,
    int ovulationCycleDay,
  ) {
    if (cycleDay >= fertileStartDay && cycleDay <= ovulationCycleDay) {
      return _ConceptionChance.high;
    }
    final rampingUp =
        cycleDay == fertileStartDay - 1 || cycleDay == fertileStartDay - 2;
    final justAfter =
        cycleDay == ovulationCycleDay + 1 || cycleDay == ovulationCycleDay + 2;
    if (rampingUp || justAfter) return _ConceptionChance.medium;
    return _ConceptionChance.low;
  }

  String _cervicalMucusFor(
    int cycleDay,
    int periodLen,
    int fertileStartDay,
    int ovulationCycleDay,
  ) {
    if (cycleDay <= periodLen) {
      return 'Bleeding — mucus observation isn\'t reliable right now.';
    }
    if (cycleDay < fertileStartDay) {
      return 'Dry or minimal, sticky mucus.';
    }
    if (cycleDay < ovulationCycleDay) {
      return 'Increasing and creamy, becoming clearer and stretchier as ovulation nears.';
    }
    if (cycleDay == ovulationCycleDay) {
      return 'Clear, stretchy, egg-white consistency — the most fertile sign.';
    }
    if (cycleDay <= ovulationCycleDay + 3) {
      return 'Mucus may become less, milky white, and cloudy again.';
    }
    return 'Dry or minimal for the rest of the cycle.';
  }

  String _periodTip(int day) {
    if (day <= 2) {
      return 'Cramps hit hardest early on — a heating pad and a little extra gentleness go a long way 🫂';
    }
    return "Still worth checking in — snacks, comfort, and no unnecessary pressure today 🍵";
  }
}

enum _ConceptionChance {
  low,
  medium,
  high;

  String get label => switch (this) {
    _ConceptionChance.low => 'LOW',
    _ConceptionChance.medium => 'MEDIUM',
    _ConceptionChance.high => 'HIGH',
  };

  Color get color => switch (this) {
    _ConceptionChance.low => Colors.grey.shade600,
    _ConceptionChance.medium => Colors.orange.shade700,
    _ConceptionChance.high => Colors.red.shade400,
  };
}

class _PeriodStatus {
  final IconData icon;
  final Color color;
  final String headline;
  final String subline;
  final String tip;
  final int cycleDay;
  final String phaseName;
  final _ConceptionChance conceptionChance;
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
