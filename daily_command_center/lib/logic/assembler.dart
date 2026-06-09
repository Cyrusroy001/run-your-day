import '../data/models.dart';

class TimelineAssembler {
  /// Merge Plan blueprint + DailyState into an ordered List<Block> (pre-drift).
  static List<Block> assembleDay(
    Plan plan,
    String templateId,
    String dayKey, {
    required bool training,
    DailyState state = const DailyState(date: ''),
  }) {
    final tmpl = plan.dayTemplates[templateId];
    if (tmpl == null) return const [];

    final deleted = state.deletedItems.toSet();

    // 1. Filter routine items by condition + deletions; resolve into Blocks.
    final items = <Block>[];
    for (final item in tmpl.routineStack) {
      if (deleted.contains(item.id)) continue;
      if (!_conditionHolds(item.condition, training)) continue;
      items.add(_itemToBlock(plan, item, dayKey, training, state));
    }

    // 2. Anchors -> Blocks (never filtered by condition; never deleted).
    final anchors = tmpl.anchors.map(_anchorToBlock).toList();

    // 3. Fold in custom tasks for this day (priority 0, never filtered).
    final customBlocks = state.addedItems
        .where((t) => state.date.isEmpty || t.date == state.date)
        .map((t) => Block(
              id: t.id,
              time: displayTime(t.startTime),
              cls: 'custom',
              label: t.label,
              estStart: _decimal24(t.startTime),
              seedStart: _decimal24(t.startTime),
              durationMinutes: t.durationMinutes,
              idealMinutes: t.durationMinutes,
              minMinutes: t.durationMinutes,
              priority: 0,
              isCustom: true,
            ))
        .toList();

    // 4. Merge + order.
    final merged = [...items, ...anchors, ...customBlocks];
    if (state.dailySequence.isNotEmpty) {
      // Reorder by explicit sequence; unknown/extra ids keep clock order after.
      final order = {for (int i = 0; i < state.dailySequence.length; i++) state.dailySequence[i]: i};
      merged.sort((a, b) {
        final ia = order[a.id] ?? 1 << 20;
        final ib = order[b.id] ?? 1 << 20;
        if (ia != ib) return ia.compareTo(ib);
        return a.estStart.compareTo(b.estStart);
      });
    } else {
      // Stable clock order by 24h decimal (items already authored in order).
      mergeSortStable(merged, (a, b) => a.estStart.compareTo(b.estStart));
    }
    return merged;
  }

  static bool _conditionHolds(String condition, bool training) {
    switch (condition) {
      case 'isTrainingDay':
        return training;
      case 'isRestDay':
        return !training;
      default:
        return true;
    }
  }

  static double _decimal24(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) + int.parse(p[1]) / 60.0;
  }

  static Block _itemToBlock(Plan plan, RoutineItem item, String dayKey, bool training, DailyState state) {
    String label = item.label;
    String? workout;
    bool isTrain = false;
    if (item.isTrain) {
      isTrain = true;
      workout = item.workoutId ?? plan.week[dayKey]?.workoutId;
      final wo = workout != null ? plan.workouts[workout] : null;
      if (wo != null) label = 'Train — ${wo.title}';
    }
    final priority = state.dailyOverrides[item.id]?.priority ?? item.priority;
    // 'goal' kind renders with the existing 'dsa' class used by today's UI.
    final cls = item.kind == 'goal' ? 'dsa' : item.kind;
    final seedDec = _decimal24(item.start);
    return Block(
      time: displayTime(item.start),
      cls: cls,
      label: label,
      desc: item.desc,
      isTrain: isTrain,
      workout: workout,
      id: item.id,
      estStart: seedDec,
      seedStart: seedDec,
      durationMinutes: item.idealDuration,
      idealMinutes: item.idealDuration,
      minMinutes: item.minDuration,
      priority: priority,
      cutoffDecimal: item.cutoffTime == null ? null : _decimal24(item.cutoffTime!),
      maxDriftMinutes: item.maxDriftMinutes,
      dropStrategy: item.dropStrategy,
    );
  }

  static Block _anchorToBlock(Anchor a) => Block(
        time: displayTime(a.start),
        cls: a.kind,
        label: a.label,
        desc: a.desc,
        id: a.id,
        estStart: _decimal24(a.start),
        isAnchor: true,
        hardAnchor: a.hard,
      );

  /// Stable merge-sort (Dart's List.sort is not guaranteed stable).
  static void mergeSortStable<T>(List<T> list, int Function(T, T) cmp) {
    if (list.length < 2) return;
    final mid = list.length ~/ 2;
    final left = list.sublist(0, mid);
    final right = list.sublist(mid);
    mergeSortStable(left, cmp);
    mergeSortStable(right, cmp);
    int i = 0, j = 0, k = 0;
    while (i < left.length && j < right.length) {
      if (cmp(left[i], right[j]) <= 0) {
        list[k++] = left[i++];
      } else {
        list[k++] = right[j++];
      }
    }
    while (i < left.length) {
      list[k++] = left[i++];
    }
    while (j < right.length) {
      list[k++] = right[j++];
    }
  }
}
