import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../services/period_service.dart';
import '../../services/user_service.dart';
import 'period_entry_sheet.dart';

/// Full period log — moved out of Period Tracker so the tracker screen can
/// stay focused on the calendar + selected-day info. Entries here are
/// editable via the same bottom sheet used to log a new period.
class PeriodRecordsScreen extends StatefulWidget {
  final String coupleId;
  const PeriodRecordsScreen({super.key, required this.coupleId});

  @override
  State<PeriodRecordsScreen> createState() => _PeriodRecordsScreenState();
}

class _PeriodRecordsScreenState extends State<PeriodRecordsScreen> {
  final PeriodService _periodService = PeriodService();
  final UserService _userService = UserService();
  late final String myId;

  String myName = '';
  String? partnerToken;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Period Records')),
      body: StreamBuilder<List<PeriodEntry>>(
        stream: _periodService.watchEntries(widget.coupleId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = [...snap.data!]
            ..sort((a, b) => b.startDate.compareTo(a.startDate));

          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No periods logged yet.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: entries
                .map(
                  (entry) => _EntryTile(
                    entry: entry,
                    onTap: () => showPeriodEntrySheet(
                      context,
                      coupleId: widget.coupleId,
                      myId: myId,
                      periodService: _periodService,
                      myName: myName,
                      partnerToken: partnerToken,
                      existing: entry,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

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
