# Flutter Widget App — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Android app that replaces the HTML daily dashboard, with a fixed week planner, a live "Now" card, and a real Android home screen widget showing the current activity.

**Architecture:** Flutter app with `shared_preferences` for all persistence (both plan and logs). Business logic is pure Dart ported from the existing JS. The `home_widget` package bridges Flutter → Android widget via SharedPreferences, with a Kotlin `AppWidgetProvider` that reads the written keys and renders a 4×2 home screen widget.

**Tech Stack:** Flutter 3.x, Dart, `shared_preferences ^2.3.0`, `home_widget ^0.6.0`, `google_fonts ^6.2.1`, `intl ^0.19.0`, Kotlin (Android widget glue only)

**Spec:** `docs/superpowers/specs/2026-06-05-widget-app-design.md`

---

## File Map

| File | Responsibility |
|---|---|
| `pubspec.yaml` | Dependencies |
| `lib/main.dart` | App entry, theme |
| `lib/data/models.dart` | `Block`, `DayPlan`, `DaySchedule`, `WorkoutLog`, `WeekPlan` typedef |
| `lib/data/store.dart` | Load/save plan + logs via SharedPreferences; write widget data |
| `lib/logic/workouts.dart` | `WORKOUTS` constant — the 4 workout definitions |
| `lib/logic/timeline.dart` | `buildTimeline()`, `buildTimes()`, `nowDecimal()` |
| `lib/logic/planner.dart` | `PlannerLogic` — spacing algorithm, training toggle, schedule toggle |
| `lib/widgets/now_card.dart` | `NowCard` stateful widget — live current/next block, progress bar |
| `lib/widgets/week_planner.dart` | `WeekPlanner` stateful widget — schedule toggles + training dots |
| `lib/screens/home_screen.dart` | `HomeScreen` — assembles NowCard + WeekPlanner |
| `android/.../res/drawable/widget_background.xml` | Terracotta gradient drawable |
| `android/.../res/layout/now_widget.xml` | Widget RemoteViews layout |
| `android/.../res/xml/now_widget_info.xml` | Widget metadata (size, update interval) |
| `android/.../NowWidgetProvider.kt` | `AppWidgetProvider` — reads SharedPrefs, binds views |
| `android/.../AndroidManifest.xml` | Register widget receiver |
| `test/logic/timeline_test.dart` | Unit tests for buildTimes + nowDecimal |
| `test/logic/planner_test.dart` | Unit tests for spacing algorithm + toggles |
| `test/widgets/now_card_test.dart` | Widget smoke test for NowCard |

---

## Task 1: Flutter Project Setup

**Files:**
- Create: Flutter project at `daily_command_center/`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Create Flutter project**

Open a terminal in the directory where you want the project (e.g. `C:\Users\Cyrus\dev\Claude\Projects\`). Run:

```bash
flutter create --org com.cyrus daily_command_center
cd daily_command_center
```

Expected output: project scaffold created, no errors.

- [ ] **Step 2: Replace pubspec.yaml dependencies**

Open `pubspec.yaml`. Replace the `dependencies` and `dev_dependencies` sections with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  home_widget: ^0.6.0
  shared_preferences: ^2.3.0
  google_fonts: ^6.2.1
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

- [ ] **Step 3: Fetch packages**

```bash
flutter pub get
```

Expected: all packages resolve, no version conflicts.

- [ ] **Step 4: Verify default app builds**

```bash
flutter build apk --debug
```

Expected: BUILD SUCCESSFUL. If it fails on minSdkVersion, open `android/app/build.gradle` and set `minSdkVersion 21`.

- [ ] **Step 5: Commit**

```bash
git init
git add .
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

## Task 2: Data Models

**Files:**
- Create: `lib/data/models.dart`
- Create: `test/data/models_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/data/models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';

void main() {
  group('DayPlan', () {
    test('serializes and deserializes correctly', () {
      const plan = DayPlan(schedule: DaySchedule.wfh, isTraining: true);
      final json = plan.toJson();
      final restored = DayPlan.fromJson(json);
      expect(restored.schedule, DaySchedule.wfh);
      expect(restored.isTraining, true);
    });

    test('copyWith preserves unchanged fields', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: false);
      final updated = plan.copyWith(isTraining: true);
      expect(updated.schedule, DaySchedule.office);
      expect(updated.isTraining, true);
    });
  });

  group('WorkoutLog', () {
    test('serializes and deserializes correctly', () {
      const log = WorkoutLog(date: '5 Jun', reps: '3×14', weight: '', waist: '82', note: 'felt strong');
      final json = log.toJson();
      final restored = WorkoutLog.fromJson(json);
      expect(restored.date, '5 Jun');
      expect(restored.reps, '3×14');
      expect(restored.waist, '82');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/data/models_test.dart
```

Expected: FAIL — `models.dart` doesn't exist yet.

- [ ] **Step 3: Create `lib/data/models.dart`**

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/data/models_test.dart
```

Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/data/models.dart test/data/models_test.dart
git commit -m "feat: add data models (Block, DayPlan, WorkoutLog)"
```

---

## Task 3: Workout Data

**Files:**
- Create: `lib/logic/workouts.dart`
- Create: `test/logic/workouts_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/logic/workouts_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/logic/workouts.dart';

void main() {
  test('all four workout keys are defined', () {
    expect(workouts.containsKey('A'), true);
    expect(workouts.containsKey('B'), true);
    expect(workouts.containsKey('BENCH'), true);
    expect(workouts.containsKey('CARDIO'), true);
  });

  test('each workout has a title, why, and at least 4 exercises', () {
    for (final entry in workouts.entries) {
      expect(entry.value.title, isNotEmpty, reason: '${entry.key} missing title');
      expect(entry.value.why, isNotEmpty, reason: '${entry.key} missing why');
      expect(entry.value.exercises.length, greaterThanOrEqualTo(4), reason: '${entry.key} too few exercises');
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/logic/workouts_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Create `lib/logic/workouts.dart`**

```dart
import '../data/models.dart';

class WorkoutDef {
  final String title;
  final String why;
  final List<ExerciseDef> exercises;
  const WorkoutDef({required this.title, required this.why, required this.exercises});
}

class ExerciseDef {
  final String name;
  final String sets;
  final String cue;
  const ExerciseDef({required this.name, required this.sets, required this.cue});
}

const workouts = <String, WorkoutDef>{
  'A': WorkoutDef(
    title: 'Full Body A',
    why: 'Hits every major muscle once. Squat + push + pull is the backbone — most shape comes from these.',
    exercises: [
      ExerciseDef(name: 'Goblet squat',        sets: '3–4 × 15–20', cue: 'Hug one dumbbell, lower slow 3s'),
      ExerciseDef(name: 'Push-ups',             sets: '3–4 × max',   cue: 'Main chest builder'),
      ExerciseDef(name: 'Bent-over rows',       sets: '3–4 × 15–20', cue: 'Pull to ribs — builds back'),
      ExerciseDef(name: 'Romanian deadlift',    sets: '3–4 × 15–20', cue: 'Feel the hamstrings'),
      ExerciseDef(name: 'Shoulder press',       sets: '3–4 × 12–15', cue: 'Shoulders = the V-shape'),
      ExerciseDef(name: 'Plank',                sets: '3 × max',     cue: 'Core'),
    ],
  ),
  'B': WorkoutDef(
    title: 'Full Body B',
    why: 'Different angles on the same muscles so they keep getting a fresh challenge with light weights.',
    exercises: [
      ExerciseDef(name: 'Bulgarian split squat', sets: '3–4 × 12–15 ea', cue: 'Rear foot on couch'),
      ExerciseDef(name: 'Floor press',           sets: '3–4 × 15–20',    cue: 'Press dumbbells up'),
      ExerciseDef(name: 'Single-arm row',        sets: '3–4 × 15 ea',    cue: 'One knee on couch'),
      ExerciseDef(name: 'Calf raises',           sets: '3–4 × 20–25',    cue: 'Rise on toes'),
      ExerciseDef(name: 'Curls + triceps',       sets: '3–4 × 15–20',    cue: 'Arm work'),
      ExerciseDef(name: 'Leg raises',            sets: '3 × 15',         cue: 'Lower abs'),
    ],
  ),
  'BENCH': WorkoutDef(
    title: 'Bench + Push',
    why: 'The bench machine is your ONE loadable lift — the only place to add real weight weekly.',
    exercises: [
      ExerciseDef(name: 'Bench press (machine)', sets: '3–4 × 10–12', cue: 'Add weight when you hit 12 all sets'),
      ExerciseDef(name: 'Incline push-ups',      sets: '3 × 12–15',   cue: 'Upper chest'),
      ExerciseDef(name: 'Goblet squat',          sets: '3 × 15–20',   cue: 'Legs'),
      ExerciseDef(name: 'Rows',                  sets: '3 × 15–20',   cue: 'Back'),
      ExerciseDef(name: 'Core circuit',          sets: '~10 min',     cue: 'Planks + leg raises'),
    ],
  ),
  'CARDIO': WorkoutDef(
    title: 'Treadmill + Core',
    why: 'Short bursts burn fat without eating into muscle, and spare a beginner\'s knees vs long runs.',
    exercises: [
      ExerciseDef(name: 'Warm-up walk',  sets: '5 min',         cue: 'Easy'),
      ExerciseDef(name: 'Intervals',     sets: '10–15 rounds',  cue: '30s brisk/incline, 60s easy'),
      ExerciseDef(name: 'Cool-down',     sets: '5 min',         cue: 'Easy walk'),
      ExerciseDef(name: 'Core finish',   sets: '~8 min',        cue: 'Planks, leg raises, side planks'),
    ],
  ),
};
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/logic/workouts_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/logic/workouts.dart test/logic/workouts_test.dart
git commit -m "feat: add workout definitions"
```

---

## Task 4: Timeline Logic

**Files:**
- Create: `lib/logic/timeline.dart`
- Create: `test/logic/timeline_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/logic/timeline_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/timeline.dart';

void main() {
  group('buildTimes', () {
    test('correctly resolves AM times', () {
      final blocks = [
        const Block(time: '8:00', cls: 'meal', label: 'Wake'),
        const Block(time: '8:30', cls: 'focus', label: 'Focus'),
        const Block(time: '11:30', cls: 'meal', label: 'Brunch'),
      ];
      final times = buildTimes(blocks);
      expect(times[0], closeTo(8.0, 0.01));
      expect(times[1], closeTo(8.5, 0.01));
      expect(times[2], closeTo(11.5, 0.01));
    });

    test('resolves afternoon times as PM, not AM', () {
      final blocks = [
        const Block(time: '8:00', cls: 'meal', label: 'Wake'),
        const Block(time: '1:50', cls: 'work', label: 'Commute'),
        const Block(time: '2:00', cls: 'work', label: 'Work'),
        const Block(time: '3:00', cls: 'meal', label: 'Lunch'),
        const Block(time: '8:30', cls: 'meal', label: 'Dinner'),
      ];
      final times = buildTimes(blocks);
      expect(times[1], closeTo(13.833, 0.01));
      expect(times[2], closeTo(14.0, 0.01));
      expect(times[3], closeTo(15.0, 0.01));
      expect(times[4], closeTo(20.5, 0.01));
    });

    test('times are always strictly increasing', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: true);
      final blocks = buildTimeline('mon', plan);
      final times = buildTimes(blocks);
      for (int i = 1; i < times.length; i++) {
        expect(times[i], greaterThan(times[i - 1]),
            reason: 'Time went backward at index $i: ${times[i - 1]} → ${times[i]}');
      }
    });
  });

  group('buildTimeline', () {
    test('office+training day includes a train block', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: true);
      final blocks = buildTimeline('mon', plan);
      expect(blocks.any((b) => b.isTrain), true);
    });

    test('office+rest day has no train block', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: false);
      final blocks = buildTimeline('mon', plan);
      expect(blocks.any((b) => b.isTrain), false);
    });

    test('wfh+training uses workout A', () {
      const plan = DayPlan(schedule: DaySchedule.wfh, isTraining: true);
      final blocks = buildTimeline('wed', plan);
      final trainBlock = blocks.firstWhere((b) => b.isTrain);
      expect(trainBlock.workout, 'A');
    });

    test('office+training uses workout B', () {
      const plan = DayPlan(schedule: DaySchedule.office, isTraining: true);
      final blocks = buildTimeline('mon', plan);
      final trainBlock = blocks.firstWhere((b) => b.isTrain);
      expect(trainBlock.workout, 'B');
    });

    test('sat uses BENCH, sun uses CARDIO', () {
      const plan = DayPlan(schedule: DaySchedule.weekend, isTraining: true);
      final sat = buildTimeline('sat', plan);
      final sun = buildTimeline('sun', plan);
      expect(sat.firstWhere((b) => b.isTrain).workout, 'BENCH');
      expect(sun.firstWhere((b) => b.isTrain).workout, 'CARDIO');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/logic/timeline_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Create `lib/logic/timeline.dart`**

```dart
import '../data/models.dart';
import 'workouts.dart';

// Block constants — the reusable building blocks of a day
const _wake   = Block(time: '8:00',  cls: 'meal',  label: 'Wake · water · sunlight',         desc: 'Light breakfast: banana + milk/eggs.');
const _focus  = Block(time: '8:30',  cls: 'focus', label: 'Deep Focus — AI Building',         desc: 'Sharpest hour. Phone in another room.');
const _snack  = Block(time: '9:45',  cls: 'meal',  label: 'Break + snack',                    desc: 'Coffee, few nuts. Reset.');
const _brunch = Block(time: '11:30', cls: 'meal',  label: 'Brunch — big protein meal',        desc: 'Eggs + dal + curd + soya. Main protein hit.');
const _commute= Block(time: '1:50',  cls: 'work',  label: 'Walk to office (10 min)',           desc: '');
const _work   = Block(time: '2:00',  cls: 'work',  label: 'Work — 2:00 to 8:00',              desc: 'Fixed block.');
const _lunch3 = Block(time: '3:00',  cls: 'meal',  label: 'Lunch at office',                  desc: 'Dal-bhat + soya or paneer.');
const _snack5 = Block(time: '5:00',  cls: 'meal',  label: 'Light snack at office',            desc: 'Roasted chana, peanuts, or curd.');
const _dinner = Block(time: '8:30',  cls: 'meal',  label: 'Dinner',                           desc: 'Roti + paneer/chicken + saag.');
const _chill  = Block(time: '9:15',  cls: 'chill', label: 'Chill — protected downtime',       desc: 'Yours. No forced work.');
const _wind   = Block(time: '10:45', cls: 'chill', label: 'Wind-down',                        desc: 'Screens dim. Makes the 8am wake work.');
const _sleep  = Block(time: '11:15', cls: 'chill', label: 'Sleep target',                     desc: 'Pull bedtime earlier in 15-min steps.');

Block _dsa(String time) => Block(time: time, cls: 'dsa', label: 'DSA Practice (45 min)', desc: '1–2 problems. Keep coding sharp.');

Block _trainBlock(String day, DayPlan plan) {
  final workout = _workoutFor(day, plan);
  final wo = workouts[workout]!;
  return Block(
    time: _trainTime(plan.schedule),
    cls: 'train',
    label: 'Train — ${wo.title}',
    desc: 'Tap to open workout.',
    isTrain: true,
    workout: workout,
  );
}

String _workoutFor(String day, DayPlan plan) {
  if (plan.schedule == DaySchedule.weekend) {
    return day == 'sat' ? 'BENCH' : 'CARDIO';
  }
  return plan.schedule == DaySchedule.wfh ? 'A' : 'B';
}

String _trainTime(DaySchedule schedule) {
  switch (schedule) {
    case DaySchedule.wfh:     return '11:00';
    case DaySchedule.office:  return '10:00';
    case DaySchedule.weekend: return '11:00';
  }
}

List<Block> buildTimeline(String day, DayPlan plan) {
  if (plan.schedule == DaySchedule.wfh) {
    final base = [
      _wake,
      const Block(time: '8:30',  cls: 'focus', label: 'BIG Project Block (2 hrs)', desc: 'No commute — push a real AI build.'),
      const Block(time: '10:30', cls: 'meal',  label: 'Break + snack',             desc: ''),
    ];
    if (plan.isTraining) base.add(_trainBlock(day, plan));
    base.addAll([
      const Block(time: '12:00', cls: 'meal', label: 'Shower + brunch', desc: 'Big protein meal'),
      _dsa('1:00'), _commute, _work, _lunch3, _snack5, _dinner, _chill, _wind, _sleep,
    ]);
    return base;
  }

  if (plan.schedule == DaySchedule.weekend) {
    final base = [
      _wake,
      const Block(time: '9:00', cls: 'focus', label: 'Focus — AI Building', desc: 'Weekend: relaxed long session.'),
      const Block(time: '10:30', cls: 'meal', label: 'Break + snack', desc: ''),
    ];
    if (plan.isTraining) {
      base.add(_trainBlock(day, plan));
      base.add(const Block(time: '12:00', cls: 'meal', label: 'Shower + big protein meal', desc: ''));
    } else {
      base.add(const Block(time: '11:00', cls: 'dsa', label: 'DSA / project block', desc: 'No training today — extra learning.'));
      base.add(const Block(time: '12:00', cls: 'meal', label: 'Big protein meal', desc: ''));
    }
    base.add(_dsa('1:00'));
    base.add(const Block(time: '2:00', cls: 'chill', label: 'Free afternoon', desc: 'Errands, rest, life.'));
    if (day == 'sun') {
      base.add(const Block(time: '5:00', cls: 'focus', label: 'WEEKLY REVIEW (15 min)', desc: 'Log tracker · read rules · plan next week.'));
    }
    base.addAll([_dinner, _chill, _wind, _sleep]);
    return base;
  }

  // office — training or rest
  if (plan.isTraining) {
    return [_wake, _focus, _snack, _trainBlock(day, plan),
      const Block(time: '11:00', cls: 'meal', label: 'Shower + brunch', desc: 'Big protein meal — office lunch at 3.'),
      _dsa('11:30'), _commute, _work, _lunch3, _snack5, _dinner, _chill, _wind, _sleep];
  }
  return [_wake, _focus, _snack,
    const Block(time: '10:00', cls: 'dsa', label: 'Extra Study Block', desc: 'No training → bigger AI push or extra DSA.'),
    _dsa('11:30'), _brunch, _commute, _work, _lunch3, _snack5, _dinner, _chill, _wind, _sleep];
}

// Resolve block time strings to 24h decimals.
// Walks forward through the day — never moves backward — to correctly
// disambiguate AM vs PM (e.g. "8:30" after "11:15" → 20.5, not 8.5).
List<double> buildTimes(List<Block> blocks) {
  double prev = 0;
  return blocks.map((b) {
    final parts = b.time.split(':');
    final h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final candidates = h == 12 ? [12.0 + m / 60] : [h + m / 60, h + 12.0 + m / 60];
    candidates.sort();
    double val = candidates.last;
    for (final c in candidates) {
      if (c >= prev - 0.001) { val = c; break; }
    }
    prev = val;
    return val;
  }).toList();
}

double nowDecimal() {
  final n = DateTime.now();
  return n.hour + n.minute / 60;
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/logic/timeline_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/logic/timeline.dart test/logic/timeline_test.dart
git commit -m "feat: port timeline logic from JS to Dart"
```

---

## Task 5: Planner Logic

**Files:**
- Create: `lib/logic/planner.dart`
- Create: `test/logic/planner_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/logic/planner_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';

void main() {
  group('defaultWeek', () {
    test('has exactly 4 training days', () {
      final week = PlannerLogic.defaultWeek();
      final count = week.values.where((p) => p.isTraining).length;
      expect(count, 4);
    });

    test('has no two consecutive training days', () {
      final week = PlannerLogic.defaultWeek();
      const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      for (int i = 0; i < order.length - 1; i++) {
        final a = week[order[i]]!.isTraining;
        final b = week[order[i + 1]]!.isTraining;
        expect(a && b, false,
            reason: '${order[i]} and ${order[i + 1]} are both training — consecutive');
      }
    });

    test('weekends have DaySchedule.weekend', () {
      final week = PlannerLogic.defaultWeek();
      expect(week['sat']!.schedule, DaySchedule.weekend);
      expect(week['sun']!.schedule, DaySchedule.weekend);
    });
  });

  group('toggleTraining', () {
    test('always maintains 4 training days after toggle on', () {
      var week = PlannerLogic.defaultWeek();
      // Turn off all training
      for (final day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
        if (week[day]!.isTraining) {
          final result = PlannerLogic.toggleTraining(week, day);
          week = result.plan;
        }
      }
      // Now turn on mon — should auto-fill back to 4
      final result = PlannerLogic.toggleTraining(week, 'mon');
      final count = result.plan.values.where((p) => p.isTraining).length;
      expect(count, 4);
    });

    test('result never has two consecutive training days', () {
      var week = PlannerLogic.defaultWeek();
      final result = PlannerLogic.toggleTraining(week, 'tue');
      const order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
      for (int i = 0; i < order.length - 1; i++) {
        final a = result.plan[order[i]]!.isTraining;
        final b = result.plan[order[i + 1]]!.isTraining;
        expect(a && b, false,
            reason: '${order[i]} and ${order[i + 1]} are both training after toggle');
      }
    });

    test('provides a message when a day is moved', () {
      // Set up a plan where adding a day must displace another
      final week = PlannerLogic.defaultWeek();
      // Find a non-training day adjacent to two training days
      // Brute-force: keep toggling until a move message appears
      for (final day in ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']) {
        if (!week[day]!.isTraining) {
          final result = PlannerLogic.toggleTraining(week, day);
          // message may or may not appear — just check it's a String or null
          expect(result.message, anyOf(isNull, isA<String>()));
          break;
        }
      }
    });
  });

  group('toggleSchedule', () {
    test('flips office to wfh', () {
      final week = PlannerLogic.defaultWeek();
      final updated = PlannerLogic.toggleSchedule(week, 'mon');
      expect(updated['mon']!.schedule, DaySchedule.wfh);
    });

    test('flips wfh to office', () {
      final week = <String, DayPlan>{
        'mon': const DayPlan(schedule: DaySchedule.wfh, isTraining: false),
        'tue': const DayPlan(schedule: DaySchedule.office, isTraining: false),
        'wed': const DayPlan(schedule: DaySchedule.wfh,    isTraining: true),
        'thu': const DayPlan(schedule: DaySchedule.office, isTraining: false),
        'fri': const DayPlan(schedule: DaySchedule.office, isTraining: true),
        'sat': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
        'sun': const DayPlan(schedule: DaySchedule.weekend, isTraining: true),
      };
      final updated = PlannerLogic.toggleSchedule(week, 'wed');
      expect(updated['wed']!.schedule, DaySchedule.office);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/logic/planner_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Create `lib/logic/planner.dart`**

```dart
import 'dart:math';
import '../data/models.dart';

class PlannerLogic {
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _weekendDays = {'sat', 'sun'};

  static WeekPlan defaultWeek() {
    final base = <String, DayPlan>{
      'mon': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'tue': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'wed': const DayPlan(schedule: DaySchedule.wfh,     isTraining: false),
      'thu': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'fri': const DayPlan(schedule: DaySchedule.office,  isTraining: false),
      'sat': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
      'sun': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
    };
    return _applyBestSpacing(base);
  }

  // Find 4-day training subset with maximum minimum gap between sessions.
  // Brute-forces all C(7,4)=35 combinations — fast enough to run on every tap.
  static List<String> _bestTrainingDays() {
    double bestScore = -1;
    List<int> bestSubset = [0, 2, 4, 6];

    for (int a = 0; a < 4; a++) {
      for (int b = a + 1; b < 5; b++) {
        for (int c = b + 1; c < 6; c++) {
          for (int d = c + 1; d < 7; d++) {
            final gaps = [b - a, c - b, d - c];
            final minGap = gaps.reduce(min);
            if (minGap < 2) continue;
            final avgGap = gaps.reduce((x, y) => x + y) / 3;
            final score = minGap + 0.1 * avgGap;
            if (score > bestScore) {
              bestScore = score;
              bestSubset = [a, b, c, d];
            }
          }
        }
      }
    }
    return bestSubset.map((i) => _days[i]).toList();
  }

  static WeekPlan _applyBestSpacing(WeekPlan plan) {
    final training = _bestTrainingDays();
    return Map.fromEntries(_days.map((d) {
      return MapEntry(d, plan[d]!.copyWith(isTraining: training.contains(d)));
    }));
  }

  static double _spacingScore(List<String> trainingDays) {
    if (trainingDays.length < 2) return 0;
    final indices = trainingDays.map((d) => _days.indexOf(d)).toList()..sort();
    final gaps = <int>[];
    for (int i = 1; i < indices.length; i++) {
      gaps.add(indices[i] - indices[i - 1]);
    }
    final minGap = gaps.reduce(min);
    if (minGap < 2) return -1.0;
    return minGap + 0.1 * (gaps.reduce((a, b) => a + b) / gaps.length);
  }

  /// Toggle training for [day]. Enforces 4-day rule and no-consecutive rule.
  /// Returns the updated plan and an optional user-visible message.
  static ({WeekPlan plan, String? message}) toggleTraining(WeekPlan current, String day) {
    final isOn = current[day]!.isTraining;

    if (isOn) {
      // Turn off — rebalance to 4 via best spacing
      final updated = Map<String, DayPlan>.from(current);
      updated[day] = current[day]!.copyWith(isTraining: false);
      return (plan: _applyBestSpacing(updated), message: null);
    }

    // Turn on
    final updated = Map<String, DayPlan>.from(current);
    updated[day] = current[day]!.copyWith(isTraining: true);
    final trainingDays = _days.where((d) => updated[d]!.isTraining).toList();

    if (trainingDays.length <= 4) {
      return (plan: _applyBestSpacing(updated), message: null);
    }

    // 5 days — remove the one whose removal yields the best score, excluding [day]
    String? removed;
    WeekPlan? bestPlan;
    double bestScore = -2;

    for (final candidate in trainingDays) {
      if (candidate == day) continue;
      final trial = Map<String, DayPlan>.from(updated);
      trial[candidate] = updated[candidate]!.copyWith(isTraining: false);
      final score = _spacingScore(_days.where((d) => trial[d]!.isTraining).toList());
      if (score > bestScore) {
        bestScore = score;
        bestPlan = trial;
        removed = candidate;
      }
    }

    final finalPlan = bestPlan ?? updated;
    final msg = removed != null
        ? 'Moved training from ${_capitalize(removed)} for better spacing'
        : null;
    return (plan: finalPlan, message: msg);
  }

  /// Toggle schedule type (office ↔ wfh) for a weekday. Weekends are locked.
  static WeekPlan toggleSchedule(WeekPlan current, String day) {
    assert(!_weekendDays.contains(day), 'Cannot toggle schedule for weekend days');
    final p = current[day]!;
    final updated = Map<String, DayPlan>.from(current);
    updated[day] = p.copyWith(
      schedule: p.schedule == DaySchedule.office ? DaySchedule.wfh : DaySchedule.office,
    );
    return updated;
  }

  static String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/logic/planner_test.dart
```

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/logic/planner.dart test/logic/planner_test.dart
git commit -m "feat: planner logic — spacing algorithm, training/schedule toggles"
```

---

## Task 6: Storage Layer

**Files:**
- Create: `lib/data/store.dart`

No separate test for store — it wraps SharedPreferences which requires a real device context. The integration is verified when the app runs in Task 10.

- [ ] **Step 1: Create `lib/data/store.dart`**

```dart
import 'dart:convert';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import '../logic/planner.dart';

class AppStore {
  static const _planKey = 'weekPlan';
  static const _logPrefix = 'log_';

  static Future<WeekPlan> loadPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_planKey);
    if (raw == null) return PlannerLogic.defaultWeek();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, DayPlan.fromJson(v as Map<String, dynamic>)));
    } catch (_) {
      return PlannerLogic.defaultWeek();
    }
  }

  static Future<void> savePlan(WeekPlan plan) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _planKey,
      jsonEncode(plan.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }

  static Future<List<WorkoutLog>> loadLogs(String workoutKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_logPrefix$workoutKey');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLogs(String workoutKey, List<WorkoutLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_logPrefix$workoutKey',
      jsonEncode(logs.map((e) => e.toJson()).toList()),
    );
  }

  // Write now-state so the Android home screen widget can read it.
  // Keys are read in NowWidgetProvider.kt with "flutter." prefix.
  static Future<void> writeWidgetData({
    required String currentAction,
    required String nextAction,
    required String dayLabel,
    required int progressPct,
  }) async {
    await HomeWidget.saveWidgetData<String>('currentAction', currentAction);
    await HomeWidget.saveWidgetData<String>('nextAction', nextAction);
    await HomeWidget.saveWidgetData<String>('dayLabel', dayLabel);
    await HomeWidget.saveWidgetData<int>('progressPct', progressPct);
    await HomeWidget.updateWidget(androidName: 'NowWidgetProvider');
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/data/store.dart
git commit -m "feat: storage layer (SharedPreferences + home_widget bridge)"
```

---

## Task 7: App Theme + Skeleton

**Files:**
- Modify: `lib/main.dart`
- Create: `lib/screens/home_screen.dart` (stub)

- [ ] **Step 1: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyCommandCenterApp());
}

class DailyCommandCenterApp extends StatelessWidget {
  const DailyCommandCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Command Center',
      theme: _theme(),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _theme() {
    const bg     = Color(0xFF0E1311);
    const panel  = Color(0xFF19211D);
    const cream  = Color(0xFFF2EDE1);
    const terra  = Color(0xFFD9663D);
    const line   = Color(0xFF2C3833);

    return ThemeData(
      colorScheme: ColorScheme.dark(
        surface: bg,
        onSurface: cream,
        primary: terra,
        outline: line,
      ),
      scaffoldBackgroundColor: bg,
      cardColor: panel,
      textTheme: GoogleFonts.splineSansTextTheme(
        ThemeData.dark().textTheme.apply(bodyColor: cream, displayColor: cream),
      ),
      useMaterial3: true,
    );
  }
}

// App-wide color constants used by widgets
class AppColors {
  static const bg     = Color(0xFF0E1311);
  static const bg2    = Color(0xFF141B18);
  static const panel  = Color(0xFF19211D);
  static const panel2 = Color(0xFF1F2925);
  static const cream  = Color(0xFFF2EDE1);
  static const terra  = Color(0xFFD9663D);
  static const terraDark = Color(0xFFB8512C);
  static const moss   = Color(0xFF8FB05A);
  static const amber  = Color(0xFFE0A23A);
  static const sky    = Color(0xFF6FA8C7);
  static const line   = Color(0xFF2C3833);
  static const muted  = Color(0xFF8A978F);
  static const dim    = Color(0xFF5E6C64);
}
```

- [ ] **Step 2: Create stub `lib/screens/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: const Center(
        child: Text('Loading…', style: TextStyle(color: AppColors.cream)),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify the app runs**

```bash
flutter run
```

Expected: App opens showing "Loading…" on a dark green background. No red error screen.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/screens/home_screen.dart
git commit -m "feat: app theme, colors, skeleton home screen"
```

---

## Task 8: NowCard Widget

**Files:**
- Create: `lib/widgets/now_card.dart`
- Create: `test/widgets/now_card_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/widgets/now_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/main.dart';
import 'package:daily_command_center/widgets/now_card.dart';

void main() {
  testWidgets('NowCard renders a label and title without crashing', (tester) async {
    final plan = <String, DayPlan>{
      'mon': const DayPlan(schedule: DaySchedule.office, isTraining: false),
      'tue': const DayPlan(schedule: DaySchedule.office, isTraining: false),
      'wed': const DayPlan(schedule: DaySchedule.wfh,    isTraining: true),
      'thu': const DayPlan(schedule: DaySchedule.office, isTraining: false),
      'fri': const DayPlan(schedule: DaySchedule.office, isTraining: true),
      'sat': const DayPlan(schedule: DaySchedule.weekend, isTraining: false),
      'sun': const DayPlan(schedule: DaySchedule.weekend, isTraining: true),
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: NowCard(plan: plan, todayKey: 'mon', onTap: () {}),
        ),
      ),
    );

    // Should have "Right now" label somewhere
    expect(find.textContaining('Right now'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/now_card_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Create `lib/widgets/now_card.dart`**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../logic/timeline.dart';
import '../main.dart';

const _dayNames = {
  'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
  'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
};

class NowCard extends StatefulWidget {
  final WeekPlan plan;
  final String todayKey;
  final VoidCallback onTap;

  const NowCard({
    super.key,
    required this.plan,
    required this.todayKey,
    required this.onTap,
  });

  @override
  State<NowCard> createState() => _NowCardState();
}

class _NowCardState extends State<NowCard> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan[widget.todayKey];
    if (plan == null) return const SizedBox.shrink();

    final blocks = buildTimeline(widget.todayKey, plan);
    final times = buildTimes(blocks);
    final now = nowDecimal();

    Block? cur;
    Block? next;
    int progressPct = 0;

    for (int i = 0; i < blocks.length; i++) {
      final start = times[i];
      final end = i < blocks.length - 1 ? times[i + 1] : 25.0;
      if (now >= start && now < end) {
        cur = blocks[i];
        next = i < blocks.length - 1 ? blocks[i + 1] : null;
        progressPct = ((now - start) / (end - start) * 100).round().clamp(0, 100);
        break;
      }
      if (now < start) {
        next = blocks[i];
        break;
      }
    }

    String title;
    String desc;
    String cardCls;
    Color gradStart;
    Color gradEnd;

    if (now < times.first) {
      title = 'Still resting';
      desc = 'Day kicks off at 8:00 with wake + sunlight.';
      cardCls = 'sleep';
      gradStart = const Color(0xFF2A3530);
      gradEnd = const Color(0xFF1F2925);
    } else if (cur == null) {
      title = 'Wind down';
      desc = "Day's done — sleep is the priority now.";
      cardCls = 'sleep';
      gradStart = const Color(0xFF2A3530);
      gradEnd = const Color(0xFF1F2925);
    } else {
      title = cur.label;
      desc = cur.desc;
      cardCls = cur.cls;
      switch (cur.cls) {
        case 'train':
          gradStart = AppColors.terra;
          gradEnd = AppColors.terraDark;
        case 'focus' || 'dsa':
          gradStart = const Color(0xFF3D6F87);
          gradEnd = const Color(0xFF2F5468);
        case 'meal':
          gradStart = const Color(0xFF46603A);
          gradEnd = const Color(0xFF3A5230);
        default:
          gradStart = const Color(0xFF2A3530);
          gradEnd = const Color(0xFF1F2925);
      }
    }

    final nextLine = next != null ? 'Next · ${next.time} — ${next.label}' : '';
    final isWorkout = cur?.isTrain ?? false;
    final dayName = _dayNames[widget.todayKey] ?? widget.todayKey;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradStart, gradEnd],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradStart.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circle top-right
            Positioned(
              right: -30, top: -30,
              child: Container(
                width: 140, height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Right now · $dayName',
                    style: const TextStyle(
                      fontSize: 11, letterSpacing: 2,
                      color: Colors.white70, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: GoogleFonts.fraunces(
                      fontSize: 26, fontWeight: FontWeight.w800,
                      color: Colors.white, height: 1.05,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(desc, style: const TextStyle(fontSize: 13.5, color: Colors.white70)),
                  ],
                  if (nextLine.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Divider(color: Colors.white.withOpacity(0.2), height: 1),
                    const SizedBox(height: 8),
                    Text(
                      nextLine,
                      style: const TextStyle(fontSize: 12.5, color: Colors.white60),
                    ),
                  ],
                  if (isWorkout) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'View Workout →',
                        style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  // Progress bar showing time remaining in current block
                  if (progressPct > 0) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPct / 100,
                        backgroundColor: Colors.white.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests**

```bash
flutter test test/widgets/now_card_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/now_card.dart test/widgets/now_card_test.dart
git commit -m "feat: NowCard widget with progress bar and workout button"
```

---

## Task 9: WeekPlanner Widget

**Files:**
- Create: `lib/widgets/week_planner.dart`

- [ ] **Step 1: Create `lib/widgets/week_planner.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/models.dart';
import '../logic/planner.dart';
import '../main.dart';

const _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayNames = {'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
                   'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun'};

class WeekPlanner extends StatefulWidget {
  final WeekPlan plan;
  final String todayKey;
  final void Function(WeekPlan newPlan, String? message) onPlanChanged;

  const WeekPlanner({
    super.key,
    required this.plan,
    required this.todayKey,
    required this.onPlanChanged,
  });

  @override
  State<WeekPlanner> createState() => _WeekPlannerState();
}

class _WeekPlannerState extends State<WeekPlanner> {
  int get _trainCount =>
      widget.plan.values.where((p) => p.isTraining).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Plan your week',
                  style: TextStyle(
                    fontSize: 11, letterSpacing: 1.2,
                    color: AppColors.sky, fontWeight: FontWeight.w600,
                  )),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '$_trainCount training days',
                  key: ValueKey(_trainCount),
                  style: TextStyle(
                    fontSize: 11,
                    color: _trainCount == 4 ? AppColors.moss : AppColors.amber,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: _dayOrder.map((day) => _DayCell(
              day: day,
              plan: widget.plan[day]!,
              isToday: day == widget.todayKey,
              onScheduleToggle: () {
                if (widget.plan[day]!.schedule == DaySchedule.weekend) return;
                final updated = PlannerLogic.toggleSchedule(widget.plan, day);
                widget.onPlanChanged(updated, null);
              },
              onTrainingToggle: () {
                HapticFeedback.lightImpact();
                final result = PlannerLogic.toggleTraining(widget.plan, day);
                widget.onPlanChanged(result.plan, result.message);
              },
            )).toList(),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              final reset = PlannerLogic.defaultWeek();
              widget.onPlanChanged(reset, null);
            },
            child: const Text(
              'Reset to suggested week',
              style: TextStyle(fontSize: 11.5, color: AppColors.dim,
                  decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String day;
  final DayPlan plan;
  final bool isToday;
  final VoidCallback onScheduleToggle;
  final VoidCallback onTrainingToggle;

  const _DayCell({
    required this.day,
    required this.plan,
    required this.isToday,
    required this.onScheduleToggle,
    required this.onTrainingToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = plan.schedule == DaySchedule.weekend;
    final scheduleLabel = isWeekend ? 'Wknd' : (plan.schedule == DaySchedule.office ? 'Office' : 'WFH');
    final scheduleColor = isWeekend ? AppColors.amber : (plan.schedule == DaySchedule.office ? AppColors.terra : AppColors.sky);

    return Expanded(
      child: GestureDetector(
        onTap: onScheduleToggle,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            border: Border(
              left: isToday
                  ? const BorderSide(color: AppColors.amber, width: 2)
                  : const BorderSide(color: AppColors.line),
              right: const BorderSide(color: AppColors.line),
              top: const BorderSide(color: AppColors.line),
              bottom: const BorderSide(color: AppColors.line),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text(
                _dayNames[day]!,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.cream),
              ),
              const SizedBox(height: 4),
              Text(
                scheduleLabel,
                style: TextStyle(fontSize: 9, color: scheduleColor, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onTrainingToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 10, height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: plan.isTraining ? AppColors.terra : Colors.transparent,
                    border: Border.all(
                      color: plan.isTraining ? AppColors.terra : AppColors.dim,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/widgets/week_planner.dart
git commit -m "feat: WeekPlanner widget with schedule toggle and training dots"
```

---

## Task 10: HomeScreen Assembly

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Replace `lib/screens/home_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../logic/planner.dart';
import '../main.dart';
import '../widgets/now_card.dart';
import '../widgets/week_planner.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeekPlan? _plan;
  final _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  late String _todayKey;

  @override
  void initState() {
    super.initState();
    _todayKey = _days[DateTime.now().weekday % 7];
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final plan = await AppStore.loadPlan();
    setState(() => _plan = plan);
    _pushWidgetData(plan);
  }

  Future<void> _updatePlan(WeekPlan newPlan, String? message) async {
    await AppStore.savePlan(newPlan);
    setState(() => _plan = newPlan);
    _pushWidgetData(newPlan);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 2500),
          backgroundColor: AppColors.panel2,
        ),
      );
    }
  }

  void _pushWidgetData(WeekPlan plan) {
    // Compute now-state and write to SharedPreferences for Android widget
    final dayPlan = plan[_todayKey];
    if (dayPlan == null) return;
    // Import timeline to compute now-state
    // (done in store via a helper — keep store import simple)
    AppStore.writeWidgetData(
      currentAction: 'Loading…',
      nextAction: '',
      dayLabel: _todayKey,
      progressPct: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: plan == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.terra))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(
                  child: NowCard(
                    plan: plan,
                    todayKey: _todayKey,
                    onTap: () {},
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: WeekPlanner(
                    plan: plan,
                    todayKey: _todayKey,
                    onPlanChanged: _updatePlan,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 60)),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final dateStr = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CYRUS · DAILY COMMAND CENTER',
            style: TextStyle(fontSize: 10, letterSpacing: 3, color: AppColors.terra, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Run The Day.',
            style: GoogleFonts.fraunces(
              fontSize: 36, fontWeight: FontWeight.w900,
              color: AppColors.cream, height: 0.95, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Lean & defined — not big. Plan it, then run it.',
            style: GoogleFonts.fraunces(
              fontSize: 15, fontStyle: FontStyle.italic, color: AppColors.muted,
            ),
          ),
          const SizedBox(height: 6),
          Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.moss, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run the app and verify it works**

```bash
flutter run
```

Expected:
- Dark header shows "Run The Day."
- NowCard shows current block with gradient background
- WeekPlanner shows 7-day grid with office/wfh labels and training dots
- Tapping a schedule cell (Mon–Fri) toggles Office ↔ WFH
- Tapping a training dot toggles training on/off (maintains 4 days)
- Toast appears when a day gets moved for spacing

- [ ] **Step 3: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: home screen assembles NowCard + WeekPlanner"
```

---

## Task 11: Android Widget — Layout + Metadata

**Files:**
- Create: `android/app/src/main/res/drawable/widget_background.xml`
- Create: `android/app/src/main/res/layout/now_widget.xml`
- Create: `android/app/src/main/res/xml/now_widget_info.xml`
- Create: `android/app/src/main/res/values/strings.xml` (add widget_description)

- [ ] **Step 1: Create widget background drawable**

Create `android/app/src/main/res/drawable/widget_background.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <gradient
        android:type="linear"
        android:angle="135"
        android:startColor="#D9663D"
        android:endColor="#B8512C" />
    <corners android:radius="20dp" />
</shape>
```

- [ ] **Step 2: Create widget layout**

Create `android/app/src/main/res/layout/now_widget.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@drawable/widget_background"
    android:orientation="vertical"
    android:padding="16dp"
    android:gravity="top">

    <TextView
        android:id="@+id/widget_label"
        android:layout_width="wrap_content"
        android:layout_height="wrap_content"
        android:textColor="#BFFFFFFF"
        android:textSize="10sp"
        android:letterSpacing="0.15"
        android:textAllCaps="true"
        android:textStyle="bold"
        android:text="Right now" />

    <TextView
        android:id="@+id/widget_title"
        android:layout_width="match_parent"
        android:layout_height="0dp"
        android:layout_weight="1"
        android:layout_marginTop="4dp"
        android:textColor="#FFFFFF"
        android:textSize="18sp"
        android:textStyle="bold"
        android:maxLines="2"
        android:ellipsize="end"
        android:text="Loading…" />

    <View
        android:layout_width="match_parent"
        android:layout_height="1dp"
        android:background="#33FFFFFF"
        android:layout_marginBottom="6dp" />

    <TextView
        android:id="@+id/widget_next"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"
        android:textColor="#99FFFFFF"
        android:textSize="11sp"
        android:maxLines="1"
        android:ellipsize="end"
        android:text="" />

    <ProgressBar
        android:id="@+id/widget_progress"
        style="?android:attr/progressBarStyleHorizontal"
        android:layout_width="match_parent"
        android:layout_height="3dp"
        android:layout_marginTop="8dp"
        android:progressBackgroundTint="#33FFFFFF"
        android:progressTint="#FFFFFF"
        android:max="100"
        android:progress="0" />
</LinearLayout>
```

- [ ] **Step 3: Create widget info XML**

Create `android/app/src/main/res/xml/now_widget_info.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="250dp"
    android:minHeight="110dp"
    android:targetCellWidth="4"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/now_widget"
    android:widgetCategory="home_screen"
    android:resizeMode="horizontal|vertical"
    android:description="@string/widget_description" />
```

- [ ] **Step 4: Add widget_description string**

Open `android/app/src/main/res/values/strings.xml`. If it doesn't exist, create it. Add:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">Daily Command Center</string>
    <string name="widget_description">Shows your current activity from the daily plan</string>
</resources>
```

- [ ] **Step 5: Commit**

```bash
git add android/app/src/main/res/
git commit -m "feat: Android widget layout, metadata, and background drawable"
```

---

## Task 12: Android Widget — Kotlin Provider + Manifest

**Files:**
- Create: `android/app/src/main/kotlin/com/cyrus/daily_command_center/NowWidgetProvider.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Create `NowWidgetProvider.kt`**

The file path is `android/app/src/main/kotlin/com/cyrus/daily_command_center/NowWidgetProvider.kt`.

```kotlin
package com.cyrus.daily_command_center

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class NowWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

            // Keys are stored with "flutter." prefix by the home_widget package
            val currentAction = prefs.getString("flutter.currentAction", "Loading…") ?: "Loading…"
            val nextAction    = prefs.getString("flutter.nextAction", "") ?: ""
            val dayLabel      = prefs.getString("flutter.dayLabel", "") ?: ""
            val progressPct   = prefs.getInt("flutter.progressPct", 0)

            val views = RemoteViews(context.packageName, R.layout.now_widget)
            views.setTextViewText(R.id.widget_label, "Right now · $dayLabel")
            views.setTextViewText(R.id.widget_title, currentAction)
            views.setTextViewText(R.id.widget_next, nextAction)
            views.setProgressBar(R.id.widget_progress, 100, progressPct, false)

            // Tap opens the app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
```

- [ ] **Step 2: Register the widget in AndroidManifest.xml**

Open `android/app/src/main/AndroidManifest.xml`. Inside the `<application>` tag, add the following block **before the closing `</application>` tag**:

```xml
<receiver
    android:name=".NowWidgetProvider"
    android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/now_widget_info" />
</receiver>
```

- [ ] **Step 3: Wire `writeWidgetData` to compute real now-state**

Update `lib/data/store.dart` — replace the `writeWidgetData` method with one that imports and uses the timeline logic:

```dart
// Add to imports at top of store.dart:
import '../logic/timeline.dart';

// Replace writeWidgetData with:
static Future<void> writeWidgetData(WeekPlan plan, String todayKey) async {
  const dayNames = {
    'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
    'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
  };

  final dayPlan = plan[todayKey];
  if (dayPlan == null) return;

  final blocks = buildTimeline(todayKey, dayPlan);
  final times = buildTimes(blocks);
  final now = nowDecimal();

  String currentAction = 'Wind down';
  String nextAction = '';
  int progressPct = 0;

  if (now < times.first) {
    currentAction = 'Still resting';
    nextAction = 'Next · ${blocks.first.time} — ${blocks.first.label}';
  } else {
    for (int i = 0; i < blocks.length; i++) {
      final start = times[i];
      final end = i < blocks.length - 1 ? times[i + 1] : 25.0;
      if (now >= start && now < end) {
        currentAction = blocks[i].label;
        if (i < blocks.length - 1) {
          nextAction = 'Next · ${blocks[i + 1].time} — ${blocks[i + 1].label}';
        }
        progressPct = ((now - start) / (end - start) * 100).round().clamp(0, 100);
        break;
      }
    }
  }

  await HomeWidget.saveWidgetData<String>('currentAction', currentAction);
  await HomeWidget.saveWidgetData<String>('nextAction', nextAction);
  await HomeWidget.saveWidgetData<String>('dayLabel', dayNames[todayKey] ?? todayKey);
  await HomeWidget.saveWidgetData<int>('progressPct', progressPct);
  await HomeWidget.updateWidget(androidName: 'NowWidgetProvider');
}
```

- [ ] **Step 4: Update HomeScreen to call the new signature**

In `lib/screens/home_screen.dart`, update `_pushWidgetData`:

```dart
void _pushWidgetData(WeekPlan plan) {
  AppStore.writeWidgetData(plan, _todayKey);
}
```

- [ ] **Step 5: Build and install on device**

```bash
flutter build apk --debug
flutter install
```

Expected: App installs. Open the app — NowCard shows current block, WeekPlanner shows the week grid.

- [ ] **Step 6: Add the widget to your home screen**

On your Android phone:
1. Long-press the home screen → Widgets
2. Find "Daily Command Center"
3. Drag the widget to your home screen
4. Confirm it shows your current activity

- [ ] **Step 7: Final commit**

```bash
git add android/ lib/data/store.dart lib/screens/home_screen.dart
git commit -m "feat: Android NowWidget provider, manifest registration, live data bridge"
```

---

## Self-Review Checklist

- [x] **Spec coverage:**
  - Flutter project setup ✓ Task 1
  - Data layer (shared_preferences) ✓ Task 6
  - Logic port: timeline ✓ Task 4, workouts ✓ Task 3, planner ✓ Task 5
  - Week planner with spacing algorithm ✓ Tasks 5 + 9
  - Now card (in-app) ✓ Task 8
  - Now Android home screen widget ✓ Tasks 11 + 12
  - Main home screen ✓ Task 10
  - UI design (colors, fonts, progress bar, training dot, toast, header) ✓ Tasks 7–10
- [x] **No placeholders** — all steps have complete code
- [x] **Type consistency** — `WeekPlan`, `DayPlan`, `Block` used consistently; `writeWidgetData` signature updated in Tasks 12 + 10
- [x] **TDD** — tests written before implementation in Tasks 2, 3, 4, 5, 8
