enum BlockStatus { pending, done, dropped }

/// Converts a 24h "HH:mm" seed time to the app's 12h display string
/// (no AM/PM, minutes zero-padded) — e.g. "20:30" -> "8:30", "14:00" -> "2:00".
String displayTime(String hhmm) {
  final parts = hhmm.split(':');
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:${m.toString().padLeft(2, '0')}';
}

class Block {
  final String time;     // 12h display string (stable; drives signature)
  final String cls;
  final String label;
  final String desc;
  final bool isTrain;
  final String? workout;
  final String? id;      // routine/anchor id (null for legacy const blocks)
  final double estStart; // 24h decimal; 0 until the engine computes it
  final int durationMinutes;
  final int idealMinutes;
  final int priority;
  final bool isAnchor;
  final bool hardAnchor;
  final BlockStatus status;
  final int minMinutes;
  final double? cutoffDecimal;
  final int? maxDriftMinutes;
  final double seedStart;
  final String? dropStrategy;
  final bool isCustom;

  const Block({
    required this.time,
    required this.cls,
    required this.label,
    this.desc = '',
    this.isTrain = false,
    this.workout,
    this.id,
    this.estStart = 0,
    this.durationMinutes = 0,
    this.idealMinutes = 0,
    this.priority = 0,
    this.isAnchor = false,
    this.hardAnchor = false,
    this.status = BlockStatus.pending,
    this.minMinutes = 0,
    this.cutoffDecimal,
    this.maxDriftMinutes,
    this.seedStart = 0,
    this.dropStrategy,
    this.isCustom = false,
  });

  /// Blocks the user actively chooses to do (counted for adherence).
  /// Passive context — the job, commute, chill, wind-down, sleep — is `work`/`chill`.
  bool get isTrackable => cls != 'work' && cls != 'chill';

  /// Stable identity within a day.
  String get signature => '$time|$label';
  bool get isCompacted => !isAnchor && idealMinutes > 0 && durationMinutes < idealMinutes;
  bool get isDropped => status == BlockStatus.dropped;

  Block copyWith({
    String? time, String? cls, String? label, String? desc, bool? isTrain, String? workout, String? id,
    double? estStart, int? durationMinutes, int? idealMinutes, int? priority,
    bool? isAnchor, bool? hardAnchor, BlockStatus? status,
    int? minMinutes, double? cutoffDecimal, int? maxDriftMinutes, double? seedStart, String? dropStrategy,
    bool? isCustom,
  }) => Block(
        time: time ?? this.time, cls: cls ?? this.cls, label: label ?? this.label, desc: desc ?? this.desc,
        isTrain: isTrain ?? this.isTrain, workout: workout ?? this.workout, id: id ?? this.id,
        estStart: estStart ?? this.estStart, durationMinutes: durationMinutes ?? this.durationMinutes,
        idealMinutes: idealMinutes ?? this.idealMinutes, priority: priority ?? this.priority,
        isAnchor: isAnchor ?? this.isAnchor, hardAnchor: hardAnchor ?? this.hardAnchor, status: status ?? this.status,
        minMinutes: minMinutes ?? this.minMinutes, cutoffDecimal: cutoffDecimal ?? this.cutoffDecimal,
        maxDriftMinutes: maxDriftMinutes ?? this.maxDriftMinutes, seedStart: seedStart ?? this.seedStart,
        dropStrategy: dropStrategy ?? this.dropStrategy,
        isCustom: isCustom ?? this.isCustom,
      );
}


class WorkoutLog {
  final String date;
  final String reps;
  final String weight;
  final String waist;
  final String note;

  const WorkoutLog({
    required this.date,
    this.reps = '',
    this.weight = '',
    this.waist = '',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'reps': reps,
    'weight': weight,
    'waist': waist,
    'note': note,
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    date: json['date'] as String,
    reps: (json['reps'] ?? '') as String,
    weight: (json['weight'] ?? '') as String,
    waist: (json['waist'] ?? '') as String,
    note: (json['note'] ?? '') as String,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// v3 Life-JSON Plan models
// ─────────────────────────────────────────────────────────────────────────

class Progression {
  final String method;
  final bool addLoad;
  final List<String> escalation;
  const Progression({required this.method, this.addLoad = false, this.escalation = const []});

  factory Progression.fromJson(Map<String, dynamic> j) => Progression(
        method: (j['method'] ?? 'double') as String,
        addLoad: (j['addLoad'] ?? false) as bool,
        escalation: ((j['escalation'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'method': method, 'addLoad': addLoad, 'escalation': escalation};
}

class ExerciseDef {
  final String name;
  final String sets;
  final String cue;
  final List<int>? repRange;
  final String? tempo;
  final bool loggable;
  final Progression? progression;
  const ExerciseDef({
    required this.name, required this.sets, required this.cue,
    this.repRange, this.tempo, this.loggable = false, this.progression,
  });

  factory ExerciseDef.fromJson(Map<String, dynamic> j) => ExerciseDef(
        name: j['name'] as String,
        sets: j['sets'] as String,
        cue: (j['cue'] ?? '') as String,
        repRange: j['repRange'] == null ? null : (j['repRange'] as List).map((e) => (e as num).toInt()).toList(),
        tempo: j['tempo'] as String?,
        loggable: (j['loggable'] ?? false) as bool,
        progression: j['progression'] == null ? null : Progression.fromJson(j['progression'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'name': name, 'sets': sets, 'cue': cue,
        if (repRange != null) 'repRange': repRange,
        if (tempo != null) 'tempo': tempo,
        'loggable': loggable,
        if (progression != null) 'progression': progression!.toJson(),
      };
}

class WorkoutDef {
  final String title;
  final String why;
  final List<ExerciseDef> exercises;
  const WorkoutDef({required this.title, required this.why, required this.exercises});

  factory WorkoutDef.fromJson(Map<String, dynamic> j) => WorkoutDef(
        title: j['title'] as String,
        why: (j['why'] ?? '') as String,
        exercises: (j['exercises'] as List).map((e) => ExerciseDef.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title, 'why': why,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

class Anchor {
  final String id;
  final String kind;
  final String label;
  final String desc;
  final String start; // 24h "HH:mm"
  final String? end;  // 24h "HH:mm"
  final bool hard;
  const Anchor({
    required this.id, required this.kind, required this.label, required this.start,
    this.desc = '', this.end, this.hard = true,
  });

  factory Anchor.fromJson(Map<String, dynamic> j) => Anchor(
        id: j['id'] as String,
        kind: (j['kind'] ?? 'work') as String,
        label: j['label'] as String,
        desc: (j['desc'] ?? '') as String,
        start: j['start'] as String,
        end: j['end'] as String?,
        hard: (j['hard'] ?? true) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'kind': kind, 'label': label,
        if (desc.isNotEmpty) 'desc': desc,
        'start': start,
        if (end != null) 'end': end,
        'hard': hard,
      };
}

class RoutineItem {
  final String id;
  final String kind;
  final String label;
  final String desc;
  final String start; // 24h "HH:mm" — seed/preferred Est Start
  final int idealDuration;
  final int minDuration;
  final int priority;
  final int? maxDriftMinutes;
  final String? cutoffTime; // 24h "HH:mm"
  final String? dropStrategy; // 'scale_to_min' | 'kill_and_notify'
  final String condition; // 'always' | 'isTrainingDay' | 'isRestDay'
  final String? workoutId;
  final String? goalId;

  const RoutineItem({
    required this.id, required this.kind, required this.label, required this.start,
    required this.idealDuration, required this.minDuration, required this.priority,
    this.desc = '', this.maxDriftMinutes, this.cutoffTime, this.dropStrategy,
    this.condition = 'always', this.workoutId, this.goalId,
  });

  bool get isTrain => kind == 'train';

  factory RoutineItem.fromJson(Map<String, dynamic> j) => RoutineItem(
        id: j['id'] as String,
        kind: j['kind'] as String,
        label: j['label'] as String,
        desc: (j['desc'] ?? '') as String,
        start: j['start'] as String,
        idealDuration: (j['idealDuration'] as num).toInt(),
        minDuration: (j['minDuration'] as num).toInt(),
        priority: (j['priority'] as num).toInt(),
        maxDriftMinutes: (j['maxDriftMinutes'] as num?)?.toInt(),
        cutoffTime: j['cutoffTime'] as String?,
        dropStrategy: j['dropStrategy'] as String?,
        condition: (j['condition'] ?? 'always') as String,
        workoutId: j['workoutId'] as String?,
        goalId: j['goalId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'kind': kind, 'label': label,
        if (desc.isNotEmpty) 'desc': desc,
        'start': start, 'idealDuration': idealDuration, 'minDuration': minDuration, 'priority': priority,
        if (maxDriftMinutes != null) 'maxDriftMinutes': maxDriftMinutes,
        if (cutoffTime != null) 'cutoffTime': cutoffTime,
        if (dropStrategy != null) 'dropStrategy': dropStrategy,
        if (condition != 'always') 'condition': condition,
        if (workoutId != null) 'workoutId': workoutId,
        if (goalId != null) 'goalId': goalId,
      };

  RoutineItem copyWith({int? idealDuration, int? minDuration, int? priority}) => RoutineItem(
        id: id, kind: kind, label: label, desc: desc, start: start,
        idealDuration: idealDuration ?? this.idealDuration,
        minDuration: minDuration ?? this.minDuration,
        priority: priority ?? this.priority,
        maxDriftMinutes: maxDriftMinutes, cutoffTime: cutoffTime, dropStrategy: dropStrategy,
        condition: condition, workoutId: workoutId, goalId: goalId,
      );
}

class DayTemplate {
  final String label;
  final String colorKey;
  final List<Anchor> anchors;
  final List<RoutineItem> routineStack;
  const DayTemplate({required this.label, required this.colorKey, required this.anchors, required this.routineStack});

  factory DayTemplate.fromJson(Map<String, dynamic> j) => DayTemplate(
        label: j['label'] as String,
        colorKey: (j['colorKey'] ?? 'terra') as String,
        anchors: ((j['anchors'] ?? const []) as List).map((e) => Anchor.fromJson(e as Map<String, dynamic>)).toList(),
        routineStack: ((j['routineStack'] ?? const []) as List).map((e) => RoutineItem.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'label': label, 'colorKey': colorKey,
        'anchors': anchors.map((e) => e.toJson()).toList(),
        'routineStack': routineStack.map((e) => e.toJson()).toList(),
      };

  DayTemplate copyWith({List<Anchor>? anchors, List<RoutineItem>? routineStack}) =>
      DayTemplate(
        label: label,
        colorKey: colorKey,
        anchors: anchors ?? this.anchors,
        routineStack: routineStack ?? this.routineStack,
      );
}

class PlanMeta {
  final String title;
  final String timezone;
  final String lifestyleArchetype;
  final String generatedAt;
  final List<String> improvementAreas;
  final List<String> equipment;
  const PlanMeta({
    this.title = '', this.timezone = '', this.lifestyleArchetype = '',
    this.generatedAt = '', this.improvementAreas = const [], this.equipment = const [],
  });

  factory PlanMeta.fromJson(Map<String, dynamic> j) => PlanMeta(
        title: (j['title'] ?? '') as String,
        timezone: (j['timezone'] ?? '') as String,
        lifestyleArchetype: (j['lifestyleArchetype'] ?? '') as String,
        generatedAt: (j['generatedAt'] ?? '') as String,
        improvementAreas: ((j['improvementAreas'] ?? const []) as List).map((e) => e as String).toList(),
        equipment: ((j['equipment'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {
        'title': title, 'timezone': timezone, 'lifestyleArchetype': lifestyleArchetype,
        'generatedAt': generatedAt, 'improvementAreas': improvementAreas, 'equipment': equipment,
      };
}

class WeekEntry {
  final String templateId;
  final bool training;
  final String? workoutId;
  const WeekEntry({required this.templateId, required this.training, this.workoutId});

  factory WeekEntry.fromJson(Map<String, dynamic> j) => WeekEntry(
        templateId: j['templateId'] as String,
        training: (j['training'] ?? false) as bool,
        workoutId: j['workoutId'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'templateId': templateId, 'training': training,
        if (workoutId != null) 'workoutId': workoutId,
      };

  WeekEntry copyWith({String? templateId, bool? training, String? workoutId}) =>
      WeekEntry(templateId: templateId ?? this.templateId, training: training ?? this.training, workoutId: workoutId ?? this.workoutId);
}

class TrainingRules {
  final int frequencyPerWeek;
  final bool avoidConsecutive;
  final List<String> rotation;
  const TrainingRules({required this.frequencyPerWeek, required this.avoidConsecutive, required this.rotation});

  factory TrainingRules.fromJson(Map<String, dynamic> j) => TrainingRules(
        frequencyPerWeek: (j['frequencyPerWeek'] as num).toInt(),
        avoidConsecutive: (j['avoidConsecutive'] ?? true) as bool,
        rotation: ((j['rotation'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'frequencyPerWeek': frequencyPerWeek, 'avoidConsecutive': avoidConsecutive, 'rotation': rotation};
}

class WeekEditorConfig {
  final List<String> toggleTemplates;
  final List<String> lockedDays;
  const WeekEditorConfig({this.toggleTemplates = const [], this.lockedDays = const []});

  factory WeekEditorConfig.fromJson(Map<String, dynamic> j) => WeekEditorConfig(
        toggleTemplates: ((j['toggleTemplates'] ?? const []) as List).map((e) => e as String).toList(),
        lockedDays: ((j['lockedDays'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'toggleTemplates': toggleTemplates, 'lockedDays': lockedDays};
}

class NutritionConfig {
  final int proteinTargetG;
  final List<String> notes;
  const NutritionConfig({this.proteinTargetG = 0, this.notes = const []});

  factory NutritionConfig.fromJson(Map<String, dynamic> j) => NutritionConfig(
        proteinTargetG: ((j['proteinTargetG'] ?? 0) as num).toInt(),
        notes: ((j['notes'] ?? const []) as List).map((e) => e as String).toList(),
      );

  Map<String, dynamic> toJson() => {'proteinTargetG': proteinTargetG, 'notes': notes};
}

class GoalDef {
  final String id;
  final String label;
  final String cadence;
  final bool loggable;
  const GoalDef({required this.id, required this.label, this.cadence = 'daily', this.loggable = false});

  factory GoalDef.fromJson(Map<String, dynamic> j) => GoalDef(
        id: j['id'] as String,
        label: j['label'] as String,
        cadence: (j['cadence'] ?? 'daily') as String,
        loggable: (j['loggable'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'cadence': cadence, 'loggable': loggable};
}

class Plan {
  final int schemaVersion;
  final PlanMeta meta;
  final Map<String, DayTemplate> dayTemplates;
  final Map<String, WeekEntry> week;
  final WeekEditorConfig weekEditor;
  final TrainingRules training;
  final Map<String, WorkoutDef> workouts;
  final NutritionConfig nutrition;
  final List<GoalDef> goals;

  const Plan({
    required this.schemaVersion, required this.meta, required this.dayTemplates,
    required this.week, required this.weekEditor, required this.training,
    required this.workouts, required this.nutrition, required this.goals,
  });

  factory Plan.fromJson(Map<String, dynamic> j) => Plan(
        schemaVersion: (j['schemaVersion'] as num).toInt(),
        meta: PlanMeta.fromJson((j['meta'] ?? const {}) as Map<String, dynamic>),
        dayTemplates: (j['dayTemplates'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, DayTemplate.fromJson(v as Map<String, dynamic>))),
        week: (j['week'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, WeekEntry.fromJson(v as Map<String, dynamic>))),
        weekEditor: WeekEditorConfig.fromJson((j['weekEditor'] ?? const {}) as Map<String, dynamic>),
        training: TrainingRules.fromJson(j['training'] as Map<String, dynamic>),
        workouts: (j['workouts'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, WorkoutDef.fromJson(v as Map<String, dynamic>))),
        nutrition: NutritionConfig.fromJson((j['nutrition'] ?? const {}) as Map<String, dynamic>),
        goals: ((j['goals'] ?? const []) as List).map((e) => GoalDef.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'meta': meta.toJson(),
        'dayTemplates': dayTemplates.map((k, v) => MapEntry(k, v.toJson())),
        'week': week.map((k, v) => MapEntry(k, v.toJson())),
        'weekEditor': weekEditor.toJson(),
        'training': training.toJson(),
        'workouts': workouts.map((k, v) => MapEntry(k, v.toJson())),
        'nutrition': nutrition.toJson(),
        'goals': goals.map((e) => e.toJson()).toList(),
      };

  Plan copyWith({Map<String, WeekEntry>? week, Map<String, DayTemplate>? dayTemplates}) => Plan(
        schemaVersion: schemaVersion, meta: meta, dayTemplates: dayTemplates ?? this.dayTemplates,
        week: week ?? this.week, weekEditor: weekEditor, training: training,
        workouts: workouts, nutrition: nutrition, goals: goals,
      );
}

// ─────────────────────────────────────────────────────────────────────────
// v3 DailyState models (ephemeral, per-day mutable reality)
// ─────────────────────────────────────────────────────────────────────────

class ItemOverride {
  final int? priority;
  const ItemOverride({this.priority});

  factory ItemOverride.fromJson(Map<String, dynamic> j) => ItemOverride(priority: (j['priority'] as num?)?.toInt());
  Map<String, dynamic> toJson() => {if (priority != null) 'priority': priority};
}

class DriftEvent {
  final String date;
  final String itemId;
  final String label;
  final String event; // 'compacted' | 'killed' | 'jettisoned'
  final int? driftMinutes;
  final int? fromDuration;
  final int? toDuration;
  final String note;
  const DriftEvent({
    required this.date, required this.itemId, required this.label, required this.event,
    this.driftMinutes, this.fromDuration, this.toDuration, this.note = '',
  });

  factory DriftEvent.fromJson(Map<String, dynamic> j) => DriftEvent(
        date: j['date'] as String,
        itemId: j['itemId'] as String,
        label: j['label'] as String,
        event: j['event'] as String,
        driftMinutes: (j['driftMinutes'] as num?)?.toInt(),
        fromDuration: (j['fromDuration'] as num?)?.toInt(),
        toDuration: (j['toDuration'] as num?)?.toInt(),
        note: (j['note'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'date': date, 'itemId': itemId, 'label': label, 'event': event,
        if (driftMinutes != null) 'driftMinutes': driftMinutes,
        if (fromDuration != null) 'fromDuration': fromDuration,
        if (toDuration != null) 'toDuration': toDuration,
        if (note.isNotEmpty) 'note': note,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom task — an ad-hoc block injected into a single day by the user.
// Persisted inside DailyState.addedItems; assembled at priority 0.
// ─────────────────────────────────────────────────────────────────────────────

class CustomTask {
  final String id;            // 'custom_<ms-timestamp>'
  final String label;
  final String startTime;     // 'HH:mm' 24-hour
  final int durationMinutes;
  final String date;          // 'yyyy-MM-dd'

  const CustomTask({
    required this.id,
    required this.label,
    required this.startTime,
    required this.durationMinutes,
    required this.date,
  });

  factory CustomTask.fromJson(Map<String, dynamic> j) => CustomTask(
        id: j['id'] as String,
        label: j['label'] as String,
        startTime: j['startTime'] as String,
        durationMinutes: j['durationMinutes'] as int,
        date: j['date'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'startTime': startTime,
        'durationMinutes': durationMinutes,
        'date': date,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// Recurring custom task — repeats on specific future dates chosen by the user.
// ─────────────────────────────────────────────────────────────────────────────

class RecurringCustomTask {
  final String id;              // 'recur_<ms-timestamp>'
  final String label;
  final String preferredTime;   // 'HH:mm' 24-hour
  final int durationMinutes;
  final List<String> activeDates; // 'yyyy-MM-dd', sorted, ≤7
  final String originTaskId;    // id of the CustomTask that spawned this

  const RecurringCustomTask({
    required this.id,
    required this.label,
    required this.preferredTime,
    required this.durationMinutes,
    required this.activeDates,
    required this.originTaskId,
  });

  factory RecurringCustomTask.fromJson(Map<String, dynamic> j) =>
      RecurringCustomTask(
        id: j['id'] as String,
        label: j['label'] as String,
        preferredTime: j['preferredTime'] as String,
        durationMinutes: (j['durationMinutes'] as num).toInt(),
        activeDates: ((j['activeDates'] ?? const []) as List)
            .map((e) => e as String)
            .toList(),
        originTaskId: j['originTaskId'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'preferredTime': preferredTime,
        'durationMinutes': durationMinutes,
        'activeDates': activeDates,
        'originTaskId': originTaskId,
      };
}

// ─────────────────────────────────────────────────────────────────────────────

class DailyState {
  final String date; // yyyy-MM-dd
  final List<String> deletedItems;
  final List<String> dailySequence;
  final Map<String, ItemOverride> dailyOverrides;
  final List<DriftEvent> driftLog;
  final List<CustomTask> addedItems;

  const DailyState({
    required this.date,
    this.deletedItems = const [],
    this.dailySequence = const [],
    this.dailyOverrides = const {},
    this.driftLog = const [],
    this.addedItems = const [],
  });

  factory DailyState.fromJson(Map<String, dynamic> j) => DailyState(
        date: j['date'] as String,
        deletedItems: ((j['deletedItems'] ?? const []) as List).map((e) => e as String).toList(),
        dailySequence: ((j['dailySequence'] ?? const []) as List).map((e) => e as String).toList(),
        dailyOverrides: ((j['dailyOverrides'] ?? const {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, ItemOverride.fromJson(v as Map<String, dynamic>))),
        driftLog: ((j['driftLog'] ?? const []) as List).map((e) => DriftEvent.fromJson(e as Map<String, dynamic>)).toList(),
        addedItems: ((j['addedItems'] ?? const []) as List).map((e) => CustomTask.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'deletedItems': deletedItems,
        'dailySequence': dailySequence,
        'dailyOverrides': dailyOverrides.map((k, v) => MapEntry(k, v.toJson())),
        'driftLog': driftLog.map((e) => e.toJson()).toList(),
        'addedItems': addedItems.map((e) => e.toJson()).toList(),
      };

  DailyState copyWith({
    List<String>? deletedItems, List<String>? dailySequence,
    Map<String, ItemOverride>? dailyOverrides, List<DriftEvent>? driftLog,
    List<CustomTask>? addedItems,
  }) => DailyState(
        date: date,
        deletedItems: deletedItems ?? this.deletedItems,
        dailySequence: dailySequence ?? this.dailySequence,
        dailyOverrides: dailyOverrides ?? this.dailyOverrides,
        driftLog: driftLog ?? this.driftLog,
        addedItems: addedItems ?? this.addedItems,
      );
}
