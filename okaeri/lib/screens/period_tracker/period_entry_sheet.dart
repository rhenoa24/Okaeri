import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/period_entry.dart';
import '../../services/period_service.dart';

String _formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Shared "Log Period" / "Edit Period" bottom sheet. Used by the Period
/// Tracker screen (logging a new period, or editing one via the selected
/// day) and the Period Records screen (editing/deleting a past entry).
Future<void> showPeriodEntrySheet(
  BuildContext context, {
  required String coupleId,
  required String myId,
  required PeriodService periodService,
  String? myName,
  String? partnerToken,
  PeriodEntry? existing,
  DateTime? initialStartDate,
}) async {
  DateTime startDate = existing != null
      ? DateTime.parse(existing.startDate)
      : (initialStartDate ?? DateTime.now());
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
                          if (endDate != null && endDate!.isBefore(startDate)) {
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
                    onChanged: (value) => setSheetState(() => ongoing = value),
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
                            await periodService.deleteEntry(
                              coupleId,
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
                                  periodService: periodService,
                                  coupleId: coupleId,
                                  myId: myId,
                                  myName: myName,
                                  partnerToken: partnerToken,
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
  required PeriodService periodService,
  required String coupleId,
  required String myId,
  required String? myName,
  required String? partnerToken,
  required PeriodEntry? existing,
  required DateTime startDate,
  required DateTime? endDate,
}) async {
  if (existing == null) {
    final id = await periodService.logPeriodStart(
      coupleId: coupleId,
      startDate: _formatDate(startDate),
      loggedBy: myId,
      senderName: myName,
      partnerToken: partnerToken,
    );
    if (endDate != null) {
      // Closed out immediately on creation — the "started" push above
      // already covers it, so no separate "ended" push here.
      await periodService.logPeriodEnd(
        coupleId: coupleId,
        entryId: id,
        endDate: _formatDate(endDate),
      );
    }
  } else {
    final wasOngoing = existing.isOngoing;
    if (endDate == null) {
      // Went back to "still ongoing" — explicitly clear the end date.
      await periodService.reopenEntry(coupleId: coupleId, entryId: existing.id);
      await periodService.updateEntry(
        coupleId: coupleId,
        entryId: existing.id,
        startDate: _formatDate(startDate),
      );
    } else if (wasOngoing) {
      // The period is actually being closed out right now — this is the
      // one case that deserves an "ended" push.
      await periodService.updateEntry(
        coupleId: coupleId,
        entryId: existing.id,
        startDate: _formatDate(startDate),
      );
      await periodService.logPeriodEnd(
        coupleId: coupleId,
        entryId: existing.id,
        endDate: _formatDate(endDate),
        senderName: myName,
        partnerToken: partnerToken,
      );
    } else {
      // Editing dates on an already-closed historical entry — no push.
      await periodService.updateEntry(
        coupleId: coupleId,
        entryId: existing.id,
        startDate: _formatDate(startDate),
        endDate: _formatDate(endDate),
      );
    }
  }
}
