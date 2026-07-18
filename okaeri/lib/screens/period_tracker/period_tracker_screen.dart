import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../models/period_settings.dart';
import '../../services/period_service.dart';
import '../../services/user_service.dart';
import '../../services/period_cycle_utils.dart';
import '../../theme/app_theme.dart';
import 'period_entry_sheet.dart';
import 'period_records_screen.dart';

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
  DateTime _selectedDay = DateTime.now();

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

  void _openRecords() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PeriodRecordsScreen(coupleId: widget.coupleId),
      ),
    );
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
  // current cycle) from the most recently logged period. Actual logged
  // days are already handled by _entryContaining above, so anything that
  // reaches the projection below is by definition not a real entry.
  _DayPhase _phaseFor(
    DateTime day,
    List<PeriodEntry> entries,
    PeriodSettings settings,
  ) {
    final target = _utc(day);

    final covering = _entryContaining(target, entries);
    if (covering != null) {
      return covering.isOngoing
          ? _DayPhase.ongoingPeriod
          : _DayPhase.loggedPeriod;
    }

    final projection = PeriodCycleUtils.projectFor(
      target,
      entries,
      settings.avgCycleLength,
    );
    if (projection == null) return _DayPhase.none;

    final periodEnd = projection.cycleStart.add(
      Duration(days: settings.avgPeriodLength - 1),
    );
    if (!target.isBefore(projection.cycleStart) && !target.isAfter(periodEnd)) {
      return _DayPhase.predictedPeriod;
    }

    if (target.isAtSameMomentAs(projection.ovulationDay)) {
      return _DayPhase.ovulation;
    }

    if (!target.isBefore(projection.fertileStart) &&
        !target.isAfter(projection.fertileEnd)) {
      return _DayPhase.fertile;
    }

    return _DayPhase.none;
  }

  // Factual cycle info (day/phase/conception/mucus) for any given day,
  // whether it's a logged period day or a projected one — used for the
  // "selected date" panel below the calendar.
  ({
    int cycleDay,
    String phaseName,
    ConceptionChance conceptionChance,
    String cervicalMucus,
  })?
  _cycleInfoFor(
    DateTime day,
    List<PeriodEntry> entries,
    PeriodSettings settings,
  ) {
    final target = _utc(day);
    final periodLen = settings.avgPeriodLength;
    final cycleLen = settings.avgCycleLength;
    final ovulationCycleDay = cycleLen - 13;
    final fertileStartDay = ovulationCycleDay - 5;

    final covering = _entryContaining(target, entries);
    if (covering != null) {
      final start = _utc(DateTime.parse(covering.startDate));
      final dayInPeriod = target.difference(start).inDays + 1;
      return (
        cycleDay: dayInPeriod,
        phaseName: 'Menstruation',
        conceptionChance: ConceptionChance.low,
        cervicalMucus: PeriodCycleUtils.cervicalMucusFor(
          dayInPeriod,
          periodLen,
          fertileStartDay,
          ovulationCycleDay,
        ),
      );
    }

    final projection = PeriodCycleUtils.projectFor(target, entries, cycleLen);
    if (projection == null) return null;

    final cycleDay = projection.cycleDay;
    return (
      cycleDay: cycleDay,
      phaseName: PeriodCycleUtils.phaseNameFor(
        cycleDay,
        periodLen,
        ovulationCycleDay,
      ),
      conceptionChance: PeriodCycleUtils.conceptionChanceFor(
        cycleDay,
        fertileStartDay,
        ovulationCycleDay,
      ),
      cervicalMucus: PeriodCycleUtils.cervicalMucusFor(
        cycleDay,
        periodLen,
        fertileStartDay,
        ovulationCycleDay,
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.list_alt_outlined),
            tooltip: 'Period Records',
            onPressed: _openRecords,
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
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () => showPeriodEntrySheet(
      //     context,
      //     coupleId: widget.coupleId,
      //     myId: myId,
      //     periodService: _periodService,
      //     myName: myName,
      //     partnerToken: partnerToken,
      //     initialStartDate: _selectedDay,
      //   ),
      //   child: const Icon(Icons.add),
      // ),
      body: StreamBuilder<List<PeriodEntry>>(
        stream: _periodService.watchEntries(widget.coupleId),
        builder: (context, entriesSnap) {
          if (!entriesSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = entriesSnap.data!;

          return StreamBuilder<PeriodSettings>(
            stream: _periodService.watchSettings(widget.coupleId),
            builder: (context, settingsSnap) {
              final settings =
                  settingsSnap.data ??
                  const PeriodSettings(avgCycleLength: 28, avgPeriodLength: 5);

              final info = _cycleInfoFor(_selectedDay, entries, settings);
              final isToday = isSameDay(_selectedDay, DateTime.now());

              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 96),
                child: Column(
                  children: [
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  DateFormat.yMMMM().format(_focusedDay),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
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
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selected, focused) {
                        setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        });
                      },
                      onPageChanged: (focusedDay) =>
                          setState(() => _focusedDay = focusedDay),
                      calendarStyle: AppTheme.calendarStyle(context),
                      headerVisible: false,
                      calendarBuilders: CalendarBuilders(
                        defaultBuilder: (context, day, focusedDay) =>
                            _dayCell(context, day, entries, settings),

                        todayBuilder: (context, day, focusedDay) =>
                            _dayCell(context, day, entries, settings),

                        selectedBuilder: (context, day, focusedDay) =>
                            _dayCell(context, day, entries, settings),

                        outsideBuilder: (context, day, focusedDay) =>
                            _dayCell(context, day, entries, settings),
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
                            color: Theme.of(context)
                                .colorScheme
                                .tertiaryContainer
                                .withValues(alpha: 0.25),
                            label: 'Fertile window',
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionHeader(
                        title: DateFormat.yMMMd().format(_selectedDay),
                        onAdd: () => showPeriodEntrySheet(
                          context,
                          coupleId: widget.coupleId,
                          myId: myId,
                          periodService: _periodService,
                          myName: myName,
                          partnerToken: partnerToken,
                          initialStartDate: _selectedDay,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: info == null
                          ? Text(
                              'No cycle data yet — log a period to see predictions for this day.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.outline,
                                fontStyle: FontStyle.italic,
                              ),
                            )
                          : CycleInfoBlock(
                              cycleDay: info.cycleDay,
                              phaseName: info.phaseName,
                              conceptionChance: info.conceptionChance,
                              cervicalMucus: info.cervicalMucus,
                            ),
                    ),
                  ],
                ),
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
    PeriodSettings settings,
  ) {
    final phase = _phaseFor(day, entries, settings);
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = isSameDay(day, DateTime.now());
    final isSelected = isSameDay(day, _selectedDay);

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
        textColor = colorScheme.onPrimary;
        break;
      case _DayPhase.fertile:
        decoration = BoxDecoration(
          color: colorScheme.tertiaryContainer.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        );
        break;
      case _DayPhase.none:
        break;
    }

    // Give today's date a subtle background if it doesn't already have one.
    if (isToday && decoration == null) {
      decoration = BoxDecoration(
        color: colorScheme.surfaceContainer,
        shape: BoxShape.circle,
      );
    }

    // Add the selection border on top of whatever decoration already exists.
    if (isSelected) {
      decoration = (decoration ?? const BoxDecoration(shape: BoxShape.circle))
          .copyWith(
            border: Border.all(
              color: colorScheme.onSurface.withValues(alpha: 0.22),
              width: 2.5,
            ),
          );
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;

  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: onAdd,
          visualDensity: VisualDensity.compact,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}
