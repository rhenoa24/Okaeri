import 'package:flutter/material.dart';
import '../models/period_entry.dart';

enum ConceptionChance {
  low,
  medium,
  high;

  String get label => switch (this) {
    ConceptionChance.low => 'LOW',
    ConceptionChance.medium => 'MEDIUM',
    ConceptionChance.high => 'HIGH',
  };

  Color color(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (this) {
      ConceptionChance.low => colorScheme.outline,
      ConceptionChance.medium => Colors.orange.shade700,
      ConceptionChance.high => colorScheme.error,
    };
  }
}

/// A projected cycle window for a specific date, anchored off the most
/// recently logged period start + the couple's average cycle length.
/// Shared by the home dashboard card ("today" status) and the Period
/// Tracker screen (any selected day on the calendar).
class CycleProjection {
  final DateTime cycleStart;
  final DateTime ovulationDay;
  final DateTime fertileStart;
  final DateTime fertileEnd; // 1 day after ovulation
  final DateTime nextPeriodStart;
  final int cycleDay; // 1-based day-of-cycle for the date this was computed for

  const CycleProjection({
    required this.cycleStart,
    required this.ovulationDay,
    required this.fertileStart,
    required this.fertileEnd,
    required this.nextPeriodStart,
    required this.cycleDay,
  });
}

class PeriodCycleUtils {
  static DateTime utcDay(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  /// Projects the cycle that `date` falls into, based on the most recently
  /// *logged* period start (not necessarily the closest one to `date`) plus
  /// the average cycle length. Returns null if nothing has been logged yet.
  static CycleProjection? projectFor(
    DateTime date,
    List<PeriodEntry> entries,
    int cycleLen,
  ) {
    if (entries.isEmpty) return null;
    final target = utcDay(date);

    final sorted = [...entries]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final anchor = utcDay(DateTime.parse(sorted.last.startDate));

    final diffDays = target.difference(anchor).inDays;
    final cycleIndex = diffDays >= 0
        ? (diffDays / cycleLen).floor()
        : ((diffDays - cycleLen + 1) / cycleLen).floor();
    final cycleStart = anchor.add(Duration(days: cycleIndex * cycleLen));
    final ovulationDay = cycleStart.add(Duration(days: cycleLen - 14));
    final fertileStart = ovulationDay.subtract(const Duration(days: 5));
    final fertileEnd = ovulationDay.add(const Duration(days: 1));
    final nextPeriodStart = cycleStart.add(Duration(days: cycleLen));
    final cycleDay = target.difference(cycleStart).inDays + 1;

    return CycleProjection(
      cycleStart: cycleStart,
      ovulationDay: ovulationDay,
      fertileStart: fertileStart,
      fertileEnd: fertileEnd,
      nextPeriodStart: nextPeriodStart,
      cycleDay: cycleDay,
    );
  }

  static String phaseNameFor(
    int cycleDay,
    int periodLen,
    int ovulationCycleDay,
  ) {
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
  static ConceptionChance conceptionChanceFor(
    int cycleDay,
    int fertileStartDay,
    int ovulationCycleDay,
  ) {
    final fertileEndDay = ovulationCycleDay + 1;

    if (cycleDay >= fertileStartDay && cycleDay <= fertileStartDay + 2) {
      return ConceptionChance.medium;
    }
    if (cycleDay > fertileStartDay + 2 && cycleDay <= ovulationCycleDay) {
      return ConceptionChance.high;
    }
    if (cycleDay == fertileEndDay) {
      return ConceptionChance.medium;
    }
    if (cycleDay > fertileEndDay && cycleDay <= fertileEndDay + 3) {
      return ConceptionChance.medium;
    }
    return ConceptionChance.low;
  }

  static String cervicalMucusFor(
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
      return 'Clear, slippery, stretchy, egg-white mucus — the most fertile type.';
    }
    if (cycleDay <= ovulationCycleDay + 3) {
      return 'Mucus becomes thicker, cloudier, and less stretchy as fertility declines.';
    }
    return 'Usually thick, sticky, or dry with little noticeable mucus.';
  }
}

/// The "Cycle Day X · Phase / Chance of Conception / Cervical mucus" block —
/// shared between the home dashboard card and the Period Tracker screen's
/// selected-date view, so both always agree with each other.
class CycleInfoBlock extends StatelessWidget {
  final int cycleDay;
  final String phaseName;
  final ConceptionChance conceptionChance;
  final String cervicalMucus;

  const CycleInfoBlock({
    super.key,
    required this.cycleDay,
    required this.phaseName,
    required this.conceptionChance,
    required this.cervicalMucus,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cycle Day $cycleDay · $phaseName Phase',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
              conceptionChance.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: conceptionChance.color(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          cervicalMucus,
          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
