enum DaySchedule { office, wfh, weekend }

class Block {
  final String time;
  final String cls;
  final String label;
  final String desc;
  final bool isTrain;
  final String? workout;

  const Block({
    required this.time,
    required this.cls,
    required this.label,
    this.desc = '',
    this.isTrain = false,
    this.workout,
  });
}

class DayPlan {
  final DaySchedule schedule;
  final bool isTraining;

  const DayPlan({required this.schedule, required this.isTraining});

  Map<String, dynamic> toJson() => {
    'schedule': schedule.name,
    'isTraining': isTraining,
  };

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
    schedule: DaySchedule.values.firstWhere((e) => e.name == json['schedule']),
    isTraining: json['isTraining'] as bool,
  );

  DayPlan copyWith({DaySchedule? schedule, bool? isTraining}) => DayPlan(
    schedule: schedule ?? this.schedule,
    isTraining: isTraining ?? this.isTraining,
  );
}

typedef WeekPlan = Map<String, DayPlan>;

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
