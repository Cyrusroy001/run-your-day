import 'package:flutter/material.dart';
import '../data/models.dart';
import '../logic/custom_task_fitter.dart';
import '../theme/app_palette.dart';
import 'add_custom_task_sheet.dart';
import 'sacrifice_picker_sheet.dart';

/// The + FAB on Today and Timeline (ADR-022 §2). Runs the existing
/// add → fit → (sacrifice) flow and hands the result to [onCommit], which
/// writes DailyState only (ADR-015). [onMessage] surfaces 'no room' inline.
class AddTaskFab extends StatelessWidget {
  final String dateIso;
  final List<Block> Function() assembled;
  final Future<void> Function(CustomTask task, List<String> dropIds) onCommit;
  final void Function(String message) onMessage;
  const AddTaskFab({super.key, required this.dateIso, required this.assembled,
      required this.onCommit, required this.onMessage});

  void _open(BuildContext context) =>
      showAddCustomTaskSheet(context, onSubmit: (label, time, dur) async {
        final blocks = assembled();
        final task = CustomTask(
            id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
            label: label, startTime: time, durationMinutes: dur, date: dateIso);
        if (CustomTaskFitter.compactionSlack(blocks) >= dur) {
          await onCommit(task, const []);
          return;
        }
        final offers = CustomTaskFitter.computeOffers(blocks, dur);
        if (offers.isEmpty) {
          onMessage('No room today — try a shorter task');
          return;
        }
        if (!context.mounted) return;
        showSacrificePickerSheet(context, offers: offers, taskLabel: label,
            onConfirm: (offer) => onCommit(task,
                offer.drop.map((b) => b.id).whereType<String>().toList()));
      });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FloatingActionButton(
      heroTag: 'add_custom_task_${dateIso}_$hashCode',
      onPressed: () => _open(context),
      backgroundColor: c.vine, foregroundColor: c.onAccent,
      child: const Icon(Icons.add),
    );
  }
}
