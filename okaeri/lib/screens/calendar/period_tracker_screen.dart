import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../models/period_settings.dart';
import '../../services/period_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _utc(DateTime d) => DateTime.utc(d.year, d.month, d.day);

enum _DayPhase {
  none,
  loggedPeriod,
  ongoingPeriod,
  predictedPeriod,
  ovulation,
  fertile,
}

class PeriodTrackerScreen extends StatefulWidget {
  final String coupleId;
  const PeriodTrackerScreen({super.key, required this.coupleId});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> {
  final PeriodService _periodService = PeriodService();
  final UserService _userService = UserService();
  late final String myId;

  String myName = '';
  String? partnerToken;

  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;
    _loadPartnerInfo();
  }

  Future<void> _loadPartnerInfo() async {
    myName = await _userService.getDisplayName(myId);

    final coupleDoc = await FirebaseFirestore.instance
        .collection('couples')
        .doc(widget.coupleId)
        .get();
    final members = List<String>.from(coupleDoc.data()?['members'] ?? []);
    final partnerId = members.firstWhere((id) => id != myId, orElse: () => '');

    if (partnerId.isNotEmpty) {
      partnerToken = await _userService.getFcmToken(partnerId);
    }
  }

  void _jumpToToday() {
    setState(() => _focusedDay = DateTime.now());
  }

  Future<void> _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _focusedDay,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2045, 12, 31),
    );
    if (picked != null) {
      setState(() => _focusedDay = picked);
    }
  }

  PeriodEntry? _entryContaining(DateTime day, List<PeriodEntry> entries) {
    for (final e in entries) {
      final start = _utc(DateTime.parse(e.startDate));
      final end = e.endDate != null
          ? _utc(DateTime.parse(e.endDate!))
          : _utc(DateTime.now());
      if (!day.isBefore(start) && !day.isAfter(end)) return e;
    }
    return null;
  }

  // ---- Log/edit bottom sheet ----

  Future<void> _openLogSheet({PeriodEntry? existing}) async {
    DateTime startDate = existing != null
        ? DateTime.parse(existing.startDate)
        : DateTime.now();
    DateTime? endDate = existing?.endDate != null
        ? DateTime.parse(existing!.endDate!)
        : null;
    bool ongoing = existing?.isOngoing ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null ? 'Log Period' : 'Edit Period',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.play_circle_outline),
                      title: const Text('First day'),
                      subtitle: Text(DateFormat.yMMMd().format(startDate)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: startDate,
                          firstDate: DateTime(2015, 1, 1),
                          lastDate: DateTime(2045, 12, 31),
                        );
                        if (picked != null) {
                          setSheetState(() {
                            startDate = picked;
                            if (endDate != null &&
                                endDate!.isBefore(startDate)) {
                              endDate = startDate;
                            }
                          });
                        }
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Still ongoing'),
                      subtitle: const Text(
                        "No last day yet — you'll add it later",
                      ),
                      value: ongoing,
                      onChanged: (value) =>
                          setSheetState(() => ongoing = value),
                    ),
                    if (!ongoing)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.stop_circle_outlined),
                        title: const Text('Last day'),
                        subtitle: Text(
                          endDate != null
                              ? DateFormat.yMMMd().format(endDate!)
                              : 'Not set',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: sheetContext,
                            initialDate: endDate ?? startDate,
                            firstDate: startDate,
                            lastDate: DateTime(2045, 12, 31),
                          );
                          if (picked != null) {
                            setSheetState(() => endDate = picked);
                          }
                        },
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (existing != null)
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(sheetContext);
                              await _periodService.deleteEntry(
                                widget.coupleId,
                                existing.id,
                              );
                            },
                            child: Text(
                              'Delete',
                              style: TextStyle(
                                color: Theme.of(sheetContext).colorScheme.error,
                              ),
                            ),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: (!ongoing && endDate == null)
                              ? null
                              : () async {
                                  Navigator.pop(sheetContext);
                                  await _saveEntry(
                                    existing: existing,
                                    startDate: startDate,
                                    endDate: ongoing ? null : endDate,
                                  );
                                },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveEntry({
    required PeriodEntry? existing,
    required DateTime startDate,
    required DateTime? endDate,
  }) async {
    if (existing == null) {
      final id = await _periodService.logPeriodStart(
        coupleId: widget.coupleId,
        startDate: _formatDate(startDate),
        loggedBy: myId,
        senderName: myName,
        partnerToken: partnerToken,
      );
      if (endDate != null) {
        // Closed out immediately on creation — the "started" push above
        // already covers it, so no separate "ended" push here.
        await _periodService.logPeriodEnd(
          coupleId: widget.coupleId,
          entryId: id,
          endDate: _formatDate(endDate),
        );
      }
    } else {
      final wasOngoing = existing.isOngoing;
      if (endDate == null) {
        // Went back to "still ongoing" — explicitly clear the end date.
        await _periodService.reopenEntry(
          coupleId: widget.coupleId,
          entryId: existing.id,
        );
        await _periodService.updateEntry(
          coupleId: widget.coupleId,
          entryId: existing.id,
          startDate: _formatDate(startDate),
        );
      } else if (wasOngoing) {
        // The period is actually being closed out right now — this is
        // the one case that deserves an "ended" push.
        await _periodService.updateEntry(
          coupleId: widget.coupleId,
          entryId: existing.id,
          startDate: _formatDate(startDate),
        );
        await _periodService.logPeriodEnd(
          coupleId: widget.coupleId,
          entryId: existing.id,
          endDate: _formatDate(endDate),
          senderName: myName,
          partnerToken: partnerToken,
        );
      } else {
        // Editing dates on an already-closed historical entry — no push.
        await _periodService.updateEntry(
          coupleId: widget.coupleId,
          entryId: existing.id,
          startDate: _formatDate(startDate),
          endDate: _formatDate(endDate),
        );
      }
    }
  }

  Future<void> _editSettings(PeriodSettings current) async {
    final cycleController = TextEditingController(
      text: current.avgCycleLength.toString(),
    );
    final periodController = TextEditingController(
      text: current.avgPeriodLength.toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cycle Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: cycleController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Average cycle length (days)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: periodController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Average period length (days)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _periodService.updateSettings(
        coupleId: widget.coupleId,
        avgCycleLength:
            int.tryParse(cycleController.text) ?? current.avgCycleLength,
        avgPeriodLength:
            int.tryParse(periodController.text) ?? current.avgPeriodLength,
      );
    }
  }

  // Projects period / ovulation / fertile phases forward (and for the
  // current cycle) from the most recently logged period, using simple
  // averages — no calendar math beyond "anchor + N * cycleLength".
  _DayPhase _phaseFor(
    DateTime day,
    List<PeriodEntry> entries,
    PeriodSettings settings,
  ) {
    final tapped = _utc(day);

    final covering = _entryContaining(tapped, entries);
    if (covering != null) {
      return covering.isOngoing
          ? _DayPhase.ongoingPeriod
          : _DayPhase.loggedPeriod;
    }

    if (entries.isEmpty) return _DayPhase.none;

    final sorted = [...entries]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final anchor = _utc(DateTime.parse(sorted.last.startDate));

    final cycleLen = settings.avgCycleLength;
    final periodLen = settings.avgPeriodLength;

    final diffDays = tapped.difference(anchor).inDays;
    final cycleIndex = diffDays >= 0
        ? (diffDays / cycleLen).floor()
        : ((diffDays - cycleLen + 1) / cycleLen).floor();
    final cycleStart = anchor.add(Duration(days: cycleIndex * cycleLen));

    if (cycleIndex >= 1) {
      final periodEnd = cycleStart.add(Duration(days: periodLen - 1));
      if (!tapped.isBefore(cycleStart) && !tapped.isAfter(periodEnd)) {
        return _DayPhase.predictedPeriod;
      }
    }

    final ovulationDay = cycleStart.add(Duration(days: cycleLen - 14));
    if (tapped.isAtSameMomentAs(ovulationDay)) return _DayPhase.ovulation;

    final fertileStart = ovulationDay.subtract(const Duration(days: 5));
    final fertileEnd = ovulationDay.add(const Duration(days: 1));
    if (!tapped.isBefore(fertileStart) && !tapped.isAfter(fertileEnd)) {
      return _DayPhase.fertile;
    }

    return _DayPhase.none;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Period Tracker'),
        actions: [
          if (!(_focusedDay.year == DateTime.now().year &&
              _focusedDay.month == DateTime.now().month))
            IconButton(
              icon: const Icon(Icons.today_outlined),
              tooltip: 'Jump to Today',
              onPressed: _jumpToToday,
            ),
          StreamBuilder<PeriodSettings>(
            stream: _periodService.watchSettings(widget.coupleId),
            builder: (context, snap) {
              final settings =
                  snap.data ??
                  const PeriodSettings(avgCycleLength: 28, avgPeriodLength: 5);
              return IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'Cycle Settings',
                onPressed: () => _editSettings(settings),
              );
            },
          ),
        ],
      ),

      body: StreamBuilder<List<PeriodEntry>>(
        stream: _periodService.watchEntries(widget.coupleId),
        builder: (context, entriesSnap) {
          if (!entriesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = entriesSnap.data!;
          final sortedDesc = [...entries]
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          return StreamBuilder<PeriodSettings>(
            stream: _periodService.watchSettings(widget.coupleId),
            builder: (context, settingsSnap) {
              final settings =
                  settingsSnap.data ??
                  const PeriodSettings(avgCycleLength: 28, avgPeriodLength: 5);
              final ongoing = entries.where((e) => e.isOngoing).toList();

              return Column(
                children: [
                  // _SummaryCard(
                  //   ongoing: ongoing.isNotEmpty ? ongoing.first : null,
                  //   entries: entries,
                  //   settings: settings,
                  // ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          color: Theme.of(context).colorScheme.outlineVariant,
                          onPressed: () {
                            setState(() {
                              _focusedDay = DateTime(
                                _focusedDay.year,
                                _focusedDay.month - 1,
                              );
                            });
                          },
                        ),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _jumpToDate,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                DateFormat.yMMMM().format(_focusedDay),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          color: Theme.of(context).colorScheme.outlineVariant,
                          onPressed: () {
                            setState(() {
                              _focusedDay = DateTime(
                                _focusedDay.year,
                                _focusedDay.month + 1,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  TableCalendar<void>(
                    firstDay: DateTime.utc(2015, 1, 1),
                    lastDay: DateTime.utc(2045, 12, 31),
                    focusedDay: _focusedDay,
                    onDaySelected: (selected, focused) {
                      // Display only — logging happens via the FAB, not taps.
                      setState(() => _focusedDay = focused);
                    },
                    onPageChanged: (focusedDay) =>
                        setState(() => _focusedDay = focusedDay),
                    calendarStyle: AppTheme.calendarStyle(context),
                    headerVisible: false,
                    calendarBuilders: CalendarBuilders(
                      defaultBuilder: (context, day, focusedDay) =>
                          _dayCell(context, day, entries, settings),
                      todayBuilder: (context, day, focusedDay) => _dayCell(
                        context,
                        day,
                        entries,
                        settings,
                        isToday: true,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 6,
                      children: [
                        _LegendDot(
                          color: Theme.of(context).colorScheme.primary,
                          label: 'Period',
                        ),
                        _LegendDot(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.25),
                          label: 'Predicted period',
                        ),
                        _LegendDot(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          label: 'Ovulation',
                        ),
                        _LegendDot(
                          color: Theme.of(context).colorScheme.tertiaryContainer
                              .withValues(alpha: 0.25),
                          label: 'Fertile window',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          'History',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _openLogSheet(),
                          visualDensity: VisualDensity.compact,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: sortedDesc.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Text(
                              'No periods logged yet.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                            children: sortedDesc
                                .map(
                                  (entry) => _EntryTile(
                                    entry: entry,
                                    onTap: () => _openLogSheet(existing: entry),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _dayCell(
    BuildContext context,
    DateTime day,
    List<PeriodEntry> entries,
    PeriodSettings settings, {
    bool isToday = false,
  }) {
    final phase = _phaseFor(day, entries, settings);
    final colorScheme = Theme.of(context).colorScheme;

    BoxDecoration? decoration;
    Color textColor = colorScheme.onSurface;

    switch (phase) {
      case _DayPhase.loggedPeriod:
        decoration = BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
        );
        textColor = colorScheme.onPrimary;
        break;
      case _DayPhase.ongoingPeriod:
        decoration = BoxDecoration(
          color: colorScheme.primary,
          shape: BoxShape.circle,
          border: Border.all(color: colorScheme.onPrimaryContainer, width: 2),
        );
        textColor = colorScheme.onPrimary;
        break;
      case _DayPhase.predictedPeriod:
        decoration = BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        );
        break;
      case _DayPhase.ovulation:
        decoration = BoxDecoration(
          color: colorScheme.tertiaryContainer,
          shape: BoxShape.circle,
        );
        break;
      case _DayPhase.fertile:
        decoration = BoxDecoration(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        );
        break;
      case _DayPhase.none:
        if (isToday) {
          decoration = BoxDecoration(
            border: Border.all(color: colorScheme.primary, width: 1.5),
            shape: BoxShape.circle,
          );
        }
        break;
    }

    return Center(
      child: Container(
        width: 36,
        height: 36,
        decoration: decoration,
        alignment: Alignment.center,
        child: Text('${day.day}', style: TextStyle(color: textColor)),
      ),
    );
  }
}

// class _SummaryCard extends StatelessWidget {
//   final PeriodEntry? ongoing;
//   final List<PeriodEntry> entries;
//   final PeriodSettings settings;

//   const _SummaryCard({
//     required this.ongoing,
//     required this.entries,
//     required this.settings,
//   });

//     @override
//     Widget build(BuildContext context) {
//       final colorScheme = Theme.of(context).colorScheme;
//       final periodService = PeriodService();
//       final prediction = periodService.predictNextPeriod(
//         entries,
//         settings.avgCycleLength,
//       );

//       String headline;
//       String? subline;

//       if (ongoing != null) {
//         final day =
//             DateTime.now().difference(DateTime.parse(ongoing!.startDate)).inDays +
//             1;
//         headline = 'Day $day of period';
//         subline =
//             'Started ${DateFormat.yMMMd().format(DateTime.parse(ongoing!.startDate))}';
//       } else if (prediction != null) {
//         final daysUntil = prediction.difference(DateTime.now()).inDays;
//         headline = daysUntil <= 0
//             ? 'Period may be starting soon'
//             : 'Next period in $daysUntil day${daysUntil == 1 ? '' : 's'}';
//         subline = 'Around ${DateFormat.yMMMd().format(prediction)}';
//       } else {
//         headline = 'No cycles logged yet';
//         subline = 'Tap the + button to log your first period';
//       }

//       return Padding(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
//         child: Card(
//           color: colorScheme.primaryContainer.withValues(alpha: 0.4),
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   headline,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w700,
//                     fontSize: 18,
//                   ),
//                 ),
//                 if (subline != null) ...[
//                   const SizedBox(height: 4),
//                   Text(subline, style: TextStyle(color: colorScheme.outline)),
//                 ],
//               ],
//             ),
//           ),
//         ),
//       );
//     }
// }

class _EntryTile extends StatelessWidget {
  final PeriodEntry entry;
  final VoidCallback onTap;

  const _EntryTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final start = DateTime.parse(entry.startDate);
    final end = entry.endDate != null ? DateTime.parse(entry.endDate!) : null;
    final rangeText = end != null
        ? '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end)}'
        : '${DateFormat.MMMd().format(start)} – ongoing';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          rangeText,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: entry.lengthInDays != null
            ? Text(
                '${entry.lengthInDays} day${entry.lengthInDays == 1 ? '' : 's'}',
              )
            : const Text('Still ongoing'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
