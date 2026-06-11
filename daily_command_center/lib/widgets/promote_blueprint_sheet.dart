import 'package:flutter/material.dart';
import '../data/models.dart' show displayTime;
import '../logic/weekly_review.dart';
import '../theme/app_palette.dart';

/// Bottom sheet for promoting a repeated custom task into the permanent plan.
/// Pre-fills from [candidate]; the user can edit label/time/duration and choose
/// which day templates to apply it to. [onConfirm] receives the final values
/// and the selected template ids — the caller does the plan write.
void showPromoteToBlueprintSheet(
  BuildContext context, {
  required PromotionCandidate candidate,
  required List<({String id, String label})> templates,
  required void Function(String label, String time, int durationMinutes, List<String> templateIds) onConfirm,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PromoteSheet(candidate: candidate, templates: templates, onConfirm: onConfirm),
  );
}

class _PromoteSheet extends StatefulWidget {
  final PromotionCandidate candidate;
  final List<({String id, String label})> templates;
  final void Function(String, String, int, List<String>) onConfirm;
  const _PromoteSheet({required this.candidate, required this.templates, required this.onConfirm});

  @override
  State<_PromoteSheet> createState() => _PromoteSheetState();
}

class _PromoteSheetState extends State<_PromoteSheet> {
  static const _durations = [15, 30, 45, 60, 90, 120];
  static const _minuteOptions = [0, 15, 30, 45];

  late final TextEditingController _labelCtrl;
  late int _selectedHour;
  late int _selectedMinuteIdx;
  late int _durationMinutes;
  final _selected = <String>{};

  late final FixedExtentScrollController _hourCtrl;
  late final FixedExtentScrollController _minCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.candidate.label);
    _durationMinutes = widget.candidate.durationMinutes;
    final parts = widget.candidate.preferredTime.split(':');
    _selectedHour = int.tryParse(parts[0]) ?? 8;
    final min = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final idx = _minuteOptions.indexOf(min);
    _selectedMinuteIdx = idx < 0 ? 0 : idx;
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

  String get _timeString =>
      '${_selectedHour.toString().padLeft(2, '0')}:${_minuteOptions[_selectedMinuteIdx].toString().padLeft(2, '0')}';

  bool get _allSelected => _selected.length == widget.templates.length && widget.templates.isNotEmpty;

  void _toggleEveryDay() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(widget.templates.map((t) => t.id));
      }
    });
  }

  void _submit() {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty || _selected.isEmpty) return;
    // Emit ids in template declaration order for stable output.
    final ids = widget.templates.where((t) => _selected.contains(t.id)).map((t) => t.id).toList();
    Navigator.of(context).pop();
    widget.onConfirm(label, _timeString, _durationMinutes, ids);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final canSubmit = _labelCtrl.text.trim().isNotEmpty && _selected.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.raise2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(color: c.dim, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Add to your plan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: c.salt)),
                  const SizedBox(height: 4),
                  Text('You did this ${widget.candidate.count}× this week.',
                      style: TextStyle(fontSize: 12.5, color: c.dim)),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _labelCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: c.salt),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: c.raise,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  Text('Start time · ${displayTime(_timeString)}',
                      style: TextStyle(fontSize: 12, color: c.dim, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  _timePicker(c),
                  const SizedBox(height: 20),

                  Text('Duration', style: TextStyle(fontSize: 12, color: c.dim, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: _durations.map((d) {
                    final selected = d == _durationMinutes;
                    return ChoiceChip(
                      label: Text('${d}m'),
                      selected: selected,
                      onSelected: (_) => setState(() => _durationMinutes = d),
                      backgroundColor: c.raise,
                      selectedColor: c.mustardDim,
                      labelStyle: TextStyle(
                        color: selected ? c.mustard : c.dim,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      side: BorderSide(color: selected ? c.mustard : Colors.transparent),
                      showCheckmark: false,
                    );
                  }).toList()),
                  const SizedBox(height: 20),

                  Text('Apply to', style: TextStyle(fontSize: 12, color: c.dim, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final t in widget.templates)
                      _applyChip(c, label: t.label, selected: _selected.contains(t.id), onTap: () {
                        setState(() {
                          _selected.contains(t.id) ? _selected.remove(t.id) : _selected.add(t.id);
                        });
                      }),
                    _applyChip(c, label: 'Every day', selected: _allSelected, onTap: _toggleEveryDay),
                  ]),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: c.tomato,
                        disabledBackgroundColor: c.raise,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Add to plan',
                          style: TextStyle(fontWeight: FontWeight.w600, color: canSubmit ? c.salt : c.dim)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _applyChip(AppPalette c, {required String label, required bool selected, required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? c.tomatoDim : c.raise,
            border: Border.all(color: selected ? c.tomato : c.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? c.tomato : c.dim,
              )),
        ),
      );

  Widget _timePicker(AppPalette c) => Container(
        height: 80,
        decoration: BoxDecoration(color: c.raise, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Expanded(child: _wheel(c, controller: _hourCtrl, count: 24,
              label: (i) => i.toString().padLeft(2, '0'),
              onChanged: (v) => setState(() => _selectedHour = v))),
          Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: c.salt)),
          Expanded(child: _wheel(c, controller: _minCtrl, count: _minuteOptions.length,
              label: (i) => _minuteOptions[i].toString().padLeft(2, '0'),
              onChanged: (v) => setState(() => _selectedMinuteIdx = v))),
        ]),
      );

  Widget _wheel(AppPalette c,
          {required FixedExtentScrollController controller,
          required int count,
          required String Function(int) label,
          required ValueChanged<int> onChanged}) =>
      ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 36,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (_, i) => Center(
            child: Text(label(i), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: c.salt)),
          ),
          childCount: count,
        ),
      );
}
