import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../models/period_settings.dart';
import '../../services/period_service.dart';
import '../../services/user_service.dart';

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  @override
  void initState() {
    super.initState();
    myId = FirebaseAuth.instance.currentUser!.uid;
  }

  Future<void> _logStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2045, 12, 31),
    );
    if (picked == null) return;
    await _periodService.logPeriodStart(
      coupleId: widget.coupleId,
      startDate: _formatDate(picked),
      loggedBy: myId,
    );
  }

  Future<void> _logEnd(PeriodEntry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.parse(entry.startDate),
      lastDate: DateTime(2045, 12, 31),
    );
    if (picked == null) return;
    await _periodService.logPeriodEnd(
      coupleId: widget.coupleId,
      entryId: entry.id,
      endDate: _formatDate(picked),
    );
  }

  Future<void> _deleteEntry(PeriodEntry entry) async {
    await _periodService.deleteEntry(widget.coupleId, entry.id);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Period Tracker'),
        actions: [
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
          final ongoing = entries.where((e) => e.isOngoing).toList();
          final past = entries.where((e) => !e.isOngoing).toList();

          return StreamBuilder<PeriodSettings>(
            stream: _periodService.watchSettings(widget.coupleId),
            builder: (context, settingsSnap) {
              final settings =
                  settingsSnap.data ??
                  const PeriodSettings(avgCycleLength: 28, avgPeriodLength: 5);
              final prediction = _periodService.predictNextPeriod(
                entries,
                settings.avgCycleLength,
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryCard(
                    ongoing: ongoing.isNotEmpty ? ongoing.first : null,
                    prediction: prediction,
                    onLogStart: ongoing.isEmpty ? _logStart : null,
                    onLogEnd: ongoing.isNotEmpty
                        ? () => _logEnd(ongoing.first)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
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
                        onPressed: ongoing.isEmpty ? _logStart : null,
                        visualDensity: VisualDensity.compact,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (past.isEmpty && ongoing.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No cycles logged yet.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    ...entries.map(
                      (entry) => _EntryTile(
                        entry: entry,
                        userService: _userService,
                        onDelete: () => _deleteEntry(entry),
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
}

class _SummaryCard extends StatelessWidget {
  final PeriodEntry? ongoing;
  final DateTime? prediction;
  final VoidCallback? onLogStart;
  final VoidCallback? onLogEnd;

  const _SummaryCard({
    required this.ongoing,
    required this.prediction,
    required this.onLogStart,
    required this.onLogEnd,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String headline;
    String? subline;

    if (ongoing != null) {
      final day =
          DateTime.now().difference(DateTime.parse(ongoing!.startDate)).inDays +
          1;
      headline = 'Day $day of period';
      subline =
          'Started ${DateFormat.yMMMd().format(DateTime.parse(ongoing!.startDate))}';
    } else if (prediction != null) {
      final daysUntil = prediction!.difference(DateTime.now()).inDays;
      headline = daysUntil <= 0
          ? 'Period may be starting soon'
          : 'Next period expected in $daysUntil day${daysUntil == 1 ? '' : 's'}';
      subline = 'Around ${DateFormat.yMMMd().format(prediction!)}';
    } else {
      headline = 'No cycles logged yet';
      subline = 'Log your first period to start predictions';
    }

    return Card(
      color: colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headline,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            if (subline != null) ...[
              const SizedBox(height: 4),
              Text(subline, style: TextStyle(color: colorScheme.outline)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (onLogStart != null)
                  FilledButton.icon(
                    onPressed: onLogStart,
                    icon: const Icon(Icons.add),
                    label: const Text('Log period start'),
                  ),
                if (onLogEnd != null)
                  FilledButton.tonalIcon(
                    onPressed: onLogEnd,
                    icon: const Icon(Icons.check),
                    label: const Text('Log period end'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  final PeriodEntry entry;
  final UserService userService;
  final VoidCallback onDelete;

  const _EntryTile({
    required this.entry,
    required this.userService,
    required this.onDelete,
  });

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
        title: Text(
          rangeText,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: entry.lengthInDays != null
            ? Text(
                '${entry.lengthInDays} day${entry.lengthInDays == 1 ? '' : 's'}',
              )
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
