import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../models/period_settings.dart';
import '../../services/period_service.dart';
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
                      Text(
                        'Cycle Day ${status.cycleDay} · ${status.phaseName} Phase',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                              color: status.conceptionChance.color(context),
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
            'Little to no noticeable cervical mucus because it\'s masked by menstrual flow.',
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
    final fertileEnd = ovulationDay.add(const Duration(days: 1));
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

  String _phaseNameFor(int cycleDay, int periodLen, int ovulationCycleDay) {
    if (cycleDay <= periodLen) return 'Menstruation';
    if (cycleDay < ovulationCycleDay) return 'Follicular';
    if (cycleDay == ovulationCycleDay) return 'Ovulation';
    return 'Luteal';
  }

  // Mirrors a typical reference app's 7-day fertile window (5 days before
  // ovulation through 1 day after) plus a tapering luteal phase:
  //   fertile day 1-3  -> MEDIUM
  //   fertile day 4-6  -> HIGH   (day 6 = ovulation)
  //   fertile day 7    -> MEDIUM (the extra day after ovulation)
  //   3 days after that -> MEDIUM (luteal taper)
  //   everything else   -> LOW
  _ConceptionChance _conceptionChanceFor(
    int cycleDay,
    int fertileStartDay,
    int ovulationCycleDay,
  ) {
    final fertileEndDay = ovulationCycleDay + 1; // day 7 of the fertile window

    if (cycleDay >= fertileStartDay && cycleDay <= fertileStartDay + 2) {
      return _ConceptionChance.medium; // fertile day 1-3
    }
    if (cycleDay > fertileStartDay + 2 && cycleDay <= ovulationCycleDay) {
      return _ConceptionChance.high; // fertile day 4-6
    }
    if (cycleDay == fertileEndDay) {
      return _ConceptionChance.medium; // fertile day 7
    }
    if (cycleDay > fertileEndDay && cycleDay <= fertileEndDay + 3) {
      return _ConceptionChance.medium; // luteal taper
    }
    return _ConceptionChance.low;
  }

  String _cervicalMucusFor(
    int cycleDay,
    int periodLen,
    int fertileStartDay,
    int ovulationCycleDay,
  ) {
    if (cycleDay <= periodLen) {
      return 'Little to no noticeable cervical mucus because it\'s masked by menstrual flow.';
    }

    if (cycleDay < fertileStartDay) {
      return 'Typically dry or sticky with only a small amount of mucus.';
    }

    if (cycleDay < ovulationCycleDay) {
      return 'Creamy or lotion-like mucus that gradually becomes clearer, wetter, and more stretchy as ovulation approaches.';
    }

    if (cycleDay == ovulationCycleDay) {
      return 'Clear, slippery, stretchy, egg-white mucus— the most fertile type.';
    }

    if (cycleDay <= ovulationCycleDay + 3) {
      return 'Mucus becomes thicker, cloudier, and less stretchy as fertility declines.';
    }

    return 'Usually thick, sticky, or dry with little noticeable mucus.';
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

  Color color(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (this) {
      _ConceptionChance.low => colorScheme.outline,
      _ConceptionChance.medium => Colors.orange.shade700,
      _ConceptionChance.high => Colors.red.shade400,
    };
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
