import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

void showAddCustomTaskSheet(
  BuildContext context, {
  required void Function(String label, String time, int durationMinutes) onSubmit,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddCustomTaskSheet(onSubmit: onSubmit),
  );
}

class _AddCustomTaskSheet extends StatefulWidget {
  final void Function(String label, String time, int durationMinutes) onSubmit;
  const _AddCustomTaskSheet({required this.onSubmit});

  @override
  State<_AddCustomTaskSheet> createState() => _AddCustomTaskSheetState();
}

class _AddCustomTaskSheetState extends State<_AddCustomTaskSheet> {
  final _labelCtrl = TextEditingController();
  int _selectedHour = 0;
  int _selectedMinuteIdx = 0; // index into [0, 15, 30, 45]
  int _durationMinutes = 30;

  static const _durations = [15, 30, 45, 60, 90, 120];
  static const _minuteOptions = [0, 15, 30, 45];

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Round up to next 15-min slot.
    final rawMin = now.minute;
    final slot = ((rawMin + 14) ~/ 15) % 4;
    final hourOffset = (rawMin + 14) ~/ 60;
    _selectedHour = (now.hour + hourOffset) % 24;
    _selectedMinuteIdx = slot;

    _hourCtrl = FixedExtentScrollController(initialItem: _selectedHour);
    _minCtrl = FixedExtentScrollController(initialItem: _selectedMinuteIdx);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  String get _timeString {
    final h = _selectedHour.toString().padLeft(2, '0');
    final m = _minuteOptions[_selectedMinuteIdx].toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) return;
    Navigator.of(context).pop();
    widget.onSubmit(label, _timeString, _durationMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final labelEmpty = _labelCtrl.text.trim().isEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.raise2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: c.dim,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Add task', style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600, color: c.salt)),
                const SizedBox(height: 16),

                // Label field
                TextField(
                  controller: _labelCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: c.salt),
                  decoration: InputDecoration(
                    hintText: 'What do you need to do?',
                    hintStyle: TextStyle(color: c.dim),
                    filled: true,
                    fillColor: c.raise,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 20),

                // Time picker label
                Text('Start time', style: TextStyle(
                  fontSize: 12, color: c.dim, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _TimePicker(
                  hourCtrl: _hourCtrl,
                  minCtrl: _minCtrl,
                  minuteOptions: _minuteOptions,
                  palette: c,
                  onHourChanged: (v) => setState(() => _selectedHour = v),
                  onMinuteChanged: (v) => setState(() => _selectedMinuteIdx = v),
                ),
                const SizedBox(height: 20),

                // Duration chips label
                Text('Duration', style: TextStyle(
                  fontSize: 12, color: c.dim, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _durations.map((d) {
                    final selected = d == _durationMinutes;
                    return ChoiceChip(
                      label: Text('${d}m'),
                      selected: selected,
                      onSelected: (_) => setState(() => _durationMinutes = d),
                      backgroundColor: c.raise,
                      selectedColor: c.vineDim,
                      labelStyle: TextStyle(
                        color: selected ? c.vine : c.dim,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: selected ? c.vine : Colors.transparent),
                      showCheckmark: false,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: labelEmpty ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.vine,
                      disabledBackgroundColor: c.raise,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Continue',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: labelEmpty ? c.dim : c.salt,
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePicker extends StatelessWidget {
  final FixedExtentScrollController hourCtrl;
  final FixedExtentScrollController minCtrl;
  final List<int> minuteOptions;
  final AppPalette palette;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const _TimePicker({
    required this.hourCtrl,
    required this.minCtrl,
    required this.minuteOptions,
    required this.palette,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = palette;
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: c.raise,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: _Wheel(
            controller: hourCtrl,
            count: 24,
            label: (i) => i.toString().padLeft(2, '0'),
            palette: c,
            onChanged: onHourChanged,
          )),
          Text(':', style: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w600, color: c.salt)),
          Expanded(child: _Wheel(
            controller: minCtrl,
            count: minuteOptions.length,
            label: (i) => minuteOptions[i].toString().padLeft(2, '0'),
            palette: c,
            onChanged: onMinuteChanged,
          )),
        ],
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int count;
  final String Function(int) label;
  final AppPalette palette;
  final ValueChanged<int> onChanged;

  const _Wheel({
    required this.controller,
    required this.count,
    required this.label,
    required this.palette,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 36,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (_, i) => Center(
          child: Text(label(i), style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: palette.salt,
          )),
        ),
        childCount: count,
      ),
    );
  }
}
