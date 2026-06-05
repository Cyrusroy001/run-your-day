# Reminders 2 Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the app to "Reminders 2", add a custom icon, add schedule-adherence tracking (mark blocks done from the live card → green state, a separate Today checklist screen with a 7-day trend), and redesign "Plan Your Week" into a roomy one-row-per-day layout with an inline caption instead of an invisible toast.

**Architecture:** Pure Flutter changes plus Android manifest/icon config. State lives in `home_screen` (single source of truth for today's done-set + plan), persisted via `shared_preferences` (new `AdherenceStore`). Per-day done signatures (`done_<date>`) and a per-day adherence summary (`adherence_<date>`) drive both today's count and the 7-day strip. No backend; the broken Android home-screen widget is out of scope.

**Tech Stack:** Flutter/Dart, `shared_preferences`, `intl`, `google_fonts`, `flutter_launcher_icons` (new dev dep), Python+Pillow (icon source art generation only).

**Spec:** [`docs/superpowers/specs/2026-06-05-reminders-2-redesign-design.md`](../specs/2026-06-05-reminders-2-redesign-design.md)

**Working directory for all commands:** `c:\Users\Cyrus\dev\Claude\Projects\run your day\daily_command_center`
**Run a single test file:** `flutter test test/path/to/file_test.dart`
**Run all tests:** `flutter test`
**Static analysis:** `flutter analyze`

> Note: `nowDecimal()` in `lib/logic/timeline.dart` reads the real clock. Two widgets below (`NowCard`, `TodayScreen`) get an optional `debugNow` test-seam parameter so time-dependent behavior is testable. Default stays `nowDecimal()`.

> Note on pending timers: `NowCard` starts a 1-minute `Timer.periodic`. In every `NowCard`/home widget test, end the test with `await tester.pumpWidget(const SizedBox());` to unmount the widget so its `dispose()` cancels the timer (otherwise `flutter_test` fails with "A Timer is still pending").

---

## File structure

| File | Responsibility | Task |
|---|---|---|
| `android/.../res/values/strings.xml` | `app_name` = Reminders 2 | 1 |
| `android/.../AndroidManifest.xml` | label → `@string/app_name` | 1 |
| `lib/main.dart` | `MaterialApp.title` | 1 |
| `pubspec.yaml` | description; icon dev-dep + config | 1, 2 |
| `tool/make_icon.py` | generate icon source PNGs | 2 |
| `assets/icon/reminders2.png`, `assets/icon/reminders2_fg.png` | icon source art | 2 |
| `lib/widgets/week_planner.dart` | one-row-per-day layout + inline caption | 3 |
| `lib/data/models.dart` | `Block.isTrackable`, `Block.signature` | 4 |
| `lib/data/adherence_store.dart` | done-set + adherence persistence + 7-day read | 5 |
| `lib/screens/today_screen.dart` | 7-day strip + today checklist | 6 |
| `lib/widgets/now_card.dart` | done/green state + View all + Mark done | 7 |
| `lib/screens/home_screen.dart` | owns `_doneToday`; wires card + nav | 7 |

---

## Task 1: Rebrand to "Reminders 2"

**Files:**
- Modify: `android/app/src/main/res/values/strings.xml`
- Modify: `android/app/src/main/AndroidManifest.xml:3`
- Modify: `lib/main.dart:17`
- Modify: `pubspec.yaml:2`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Read the current `test/widget_test.dart`** so you replace it knowingly.

Run: `cat test/widget_test.dart` (PowerShell: `Get-Content test/widget_test.dart`)

- [ ] **Step 2: Write the failing test** — replace the entire contents of `test/widget_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/main.dart';

void main() {
  testWidgets('app launcher title is "Reminders 2"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const DailyCommandCenterApp());
    await tester.pumpAndSettle(); // let async plan-load finish while mounted
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Reminders 2');
    await tester.pumpWidget(const SizedBox()); // dispose NowCard's periodic timer
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/widget_test.dart`
Expected: FAIL — `Expected: 'Reminders 2'  Actual: 'Daily Command Center'`

- [ ] **Step 4: Update `lib/main.dart`** — change the title:

```dart
      title: 'Reminders 2',
```
(replaces `title: 'Daily Command Center',`)

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/widget_test.dart`
Expected: PASS

- [ ] **Step 6: Update the Android name.** In `android/app/src/main/res/values/strings.xml` set:

```xml
    <string name="app_name">Reminders 2</string>
```

In `android/app/src/main/AndroidManifest.xml` change the hardcoded label to reference the string resource (DRY):

```xml
        android:label="@string/app_name"
```
(replaces `android:label="Daily Command Center"`)

- [ ] **Step 7: Update `pubspec.yaml` description** (line 2):

```yaml
description: "Reminders 2 — Cyrus's personal daily dashboard and schedule tracker."
```

- [ ] **Step 8: Analyze + full test run**

Run: `flutter analyze` → Expected: No issues (or only pre-existing infos)
Run: `flutter test` → Expected: all pass

- [ ] **Step 9: Commit**

```bash
git add daily_command_center/lib/main.dart daily_command_center/android/app/src/main/res/values/strings.xml daily_command_center/android/app/src/main/AndroidManifest.xml daily_command_center/pubspec.yaml daily_command_center/test/widget_test.dart
git commit -m "feat: rebrand app to Reminders 2"
```

---

## Task 2: Custom app icon ("superior check")

No unit test (icon generation is a build artifact). Verification = the generator runs cleanly and mipmaps change.

**Files:**
- Create: `tool/make_icon.py`
- Create: `assets/icon/reminders2.png`, `assets/icon/reminders2_fg.png` (generated)
- Modify: `pubspec.yaml`

- [ ] **Step 1: Create `tool/make_icon.py`** with this exact content:

```python
from PIL import Image, ImageDraw, ImageFont
import os

SIZE = 1024
TERRA_TOP = (217, 102, 61)   # D9663D
TERRA_BOT = (184, 81, 44)    # B8512C
CREAM = (242, 237, 225)      # F2EDE1
DARK = (14, 19, 17)          # 0E1311

os.makedirs('assets/icon', exist_ok=True)


def gradient(size, top, bot):
    img = Image.new('RGB', (size, size), top)
    d = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        d.line([(0, y), (size, y)], fill=(
            int(top[0] + (bot[0] - top[0]) * t),
            int(top[1] + (bot[1] - top[1]) * t),
            int(top[2] + (bot[2] - top[2]) * t),
        ))
    return img


def draw_check(d, cx, cy, scale, color, width):
    p1 = (cx - 0.42 * scale, cy + 0.02 * scale)
    p2 = (cx - 0.12 * scale, cy + 0.34 * scale)
    p3 = (cx + 0.46 * scale, cy - 0.34 * scale)
    d.line([p1, p2, p3], fill=color, width=width, joint='curve')
    r = width // 2
    for p in (p1, p2, p3):
        d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def serif_font(size):
    for path in [r'C:\Windows\Fonts\georgiab.ttf', r'C:\Windows\Fonts\timesbd.ttf',
                 r'C:\Windows\Fonts\georgia.ttf', r'C:\Windows\Fonts\times.ttf']:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


# Legacy icon: full-bleed gradient + check + serif "2"
legacy = gradient(SIZE, TERRA_TOP, TERRA_BOT)
d = ImageDraw.Draw(legacy)
draw_check(d, SIZE * 0.5, SIZE * 0.46, SIZE * 0.5, CREAM, int(SIZE * 0.09))
font = serif_font(int(SIZE * 0.22))
bbox = d.textbbox((0, 0), '2', font=font)
tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
d.text((SIZE * 0.72 - tw / 2, SIZE * 0.78 - th / 2), '2', font=font, fill=DARK)
legacy.save('assets/icon/reminders2.png')

# Adaptive foreground: transparent, check centered in safe zone, no "2"
fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
d2 = ImageDraw.Draw(fg)
draw_check(d2, SIZE * 0.5, SIZE * 0.5, SIZE * 0.42, CREAM, int(SIZE * 0.085))
fg.save('assets/icon/reminders2_fg.png')

print('icons written to assets/icon/')
```

- [ ] **Step 2: Ensure Pillow is installed, then run the script**

Run (from the `daily_command_center` directory):
```powershell
python -m pip install --quiet Pillow
python tool/make_icon.py
```
Expected: `icons written to assets/icon/` and two PNGs exist at `assets/icon/`.
If `python` is not found, try `py tool/make_icon.py`. If Pillow cannot install, STOP and report — do not fake the icon.

- [ ] **Step 3: Add `flutter_launcher_icons` dev dependency.** In `pubspec.yaml` under `dev_dependencies:` add:

```yaml
  flutter_launcher_icons: ^0.13.1
```

- [ ] **Step 4: Add the icon config.** Add this top-level block to `pubspec.yaml` (e.g. just below the `dev_dependencies:` section, at column 0):

```yaml
flutter_launcher_icons:
  android: true
  ios: false
  image_path: "assets/icon/reminders2.png"
  min_sdk_android: 21
  adaptive_icon_background: "#C25B34"
  adaptive_icon_foreground: "assets/icon/reminders2_fg.png"
```

- [ ] **Step 5: Resolve packages + generate icons**

Run:
```powershell
flutter pub get
dart run flutter_launcher_icons
```
Expected: ends with `✓ Successfully generated launcher icons`.

- [ ] **Step 6: Verify the mipmaps changed and adaptive XML was created**

Run: `git status --short daily_command_center/android/app/src/main/res`
Expected: modified `mipmap-*/ic_launcher.png` and new `mipmap-anydpi-v26/ic_launcher.xml` + `values/colors.xml` (or `ic_launcher_background`). `flutter analyze` still clean.

- [ ] **Step 7: Commit**

```bash
git add daily_command_center/tool/make_icon.py daily_command_center/assets/icon daily_command_center/pubspec.yaml daily_command_center/pubspec.lock daily_command_center/android/app/src/main/res
git commit -m "feat: add Reminders 2 launcher icon (superior check)"
```

---

## Task 3: "Plan Your Week" one-row-per-day layout + inline caption

Replaces the 7-column grid (10px training dot, nested gestures, invisible SnackBar). The planner now owns and shows the auto-move caption; `home_screen` stops showing a SnackBar and `onPlanChanged` drops its message argument.

**Files:**
- Modify (rewrite): `lib/widgets/week_planner.dart`
- Modify: `lib/screens/home_screen.dart:35-49,69-75`
- Test: `test/widgets/week_planner_test.dart` (create)

- [ ] **Step 1: Write the failing tests** — create `test/widgets/week_planner_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';
import 'package:daily_command_center/widgets/week_planner.dart';

Widget _host(WeekPlan plan, void Function(WeekPlan) onChanged) =>
    MaterialApp(home: Scaffold(body: WeekPlanner(
      plan: plan, todayKey: 'mon', onPlanChanged: onChanged)));

void main() {
  testWidgets('renders all seven day labels', (tester) async {
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (_) {}));
    for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
      expect(find.text(d), findsOneWidget);
    }
  });

  testWidgets('tapping a weekday schedule chip toggles office<->wfh', (tester) async {
    WeekPlan? updated;
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (p) => updated = p));
    expect(PlannerLogic.defaultWeek()['mon']!.schedule, DaySchedule.office);
    await tester.tap(find.byKey(const Key('sched-mon')));
    await tester.pump();
    expect(updated!['mon']!.schedule, DaySchedule.wfh);
  });

  testWidgets('weekend schedule chip does nothing', (tester) async {
    WeekPlan? updated;
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (p) => updated = p));
    await tester.tap(find.byKey(const Key('sched-sat')));
    await tester.pump();
    expect(updated, isNull);
  });

  testWidgets('toggling an extra training day shows the move caption', (tester) async {
    // defaultWeek trains mon/wed/fri/sun; turning tue on forces a spacing move.
    await tester.pumpWidget(_host(PlannerLogic.defaultWeek(), (_) {}));
    await tester.tap(find.byKey(const Key('train-tue')));
    await tester.pump();
    expect(find.textContaining('Moved training'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/widgets/week_planner_test.dart`
Expected: FAIL (compile error — `WeekPlanner.onPlanChanged` currently takes `(WeekPlan, String?)`, and keys `sched-*`/`train-*` don't exist).

- [ ] **Step 3: Rewrite `lib/widgets/week_planner.dart`** with this exact content:

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../logic/planner.dart';
import '../main.dart';

const _dayOrder = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const _dayNames = {
  'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
  'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
};

class WeekPlanner extends StatefulWidget {
  final WeekPlan plan;
  final String todayKey;
  final void Function(WeekPlan newPlan) onPlanChanged;

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
  String? _caption;
  Timer? _captionTimer;

  int get _trainCount => widget.plan.values.where((p) => p.isTraining).length;

  @override
  void dispose() {
    _captionTimer?.cancel();
    super.dispose();
  }

  void _showCaption(String? msg) {
    _captionTimer?.cancel();
    setState(() => _caption = msg);
    if (msg != null) {
      _captionTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _caption = null);
      });
    }
  }

  void _onSchedule(String day) {
    if (widget.plan[day]!.schedule == DaySchedule.weekend) return;
    widget.onPlanChanged(PlannerLogic.toggleSchedule(widget.plan, day));
  }

  void _onTraining(String day) {
    HapticFeedback.lightImpact();
    final result = PlannerLogic.toggleTraining(widget.plan, day);
    _showCaption(result.message);
    widget.onPlanChanged(result.plan);
  }

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
              const Text('PLAN YOUR WEEK',
                  style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.sky, fontWeight: FontWeight.w600)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text('$_trainCount training days',
                    key: ValueKey(_trainCount),
                    style: TextStyle(fontSize: 11, color: _trainCount == 4 ? AppColors.moss : AppColors.amber, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._dayOrder.map((day) => _DayRow(
                day: day,
                plan: widget.plan[day]!,
                isToday: day == widget.todayKey,
                onSchedule: () => _onSchedule(day),
                onTraining: () => _onTraining(day),
              )),
          if (_caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_caption!, style: const TextStyle(fontSize: 12, color: AppColors.sky)),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => widget.onPlanChanged(PlannerLogic.defaultWeek()),
            child: const Text('Reset to suggested week',
                style: TextStyle(fontSize: 11.5, color: AppColors.dim, decoration: TextDecoration.underline, decorationColor: AppColors.dim)),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final String day;
  final DayPlan plan;
  final bool isToday;
  final VoidCallback onSchedule;
  final VoidCallback onTraining;

  const _DayRow({
    required this.day,
    required this.plan,
    required this.isToday,
    required this.onSchedule,
    required this.onTraining,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = plan.schedule == DaySchedule.weekend;
    final schedLabel = isWeekend ? 'Weekend' : (plan.schedule == DaySchedule.office ? 'Office' : 'WFH');
    final schedColor = isWeekend ? AppColors.amber : (plan.schedule == DaySchedule.office ? AppColors.terra : AppColors.sky);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: isToday ? AppColors.amber : Colors.transparent, width: 3)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(width: 38, child: Text(_dayNames[day]!,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.cream))),
          const SizedBox(width: 8),
          GestureDetector(
            key: Key('sched-$day'),
            onTap: onSchedule,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: schedColor.withValues(alpha: 0.12),
                border: Border.all(color: schedColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(schedLabel, style: TextStyle(fontSize: 12, color: schedColor, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(),
          Text(plan.isTraining ? 'Train' : 'Rest',
              style: TextStyle(fontSize: 11, color: plan.isTraining ? AppColors.moss : AppColors.dim, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          GestureDetector(
            key: Key('train-$day'),
            onTap: onTraining,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 48,
              height: 28,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: plan.isTraining ? AppColors.terra : AppColors.line,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 180),
                alignment: plan.isTraining ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 22, height: 22,
                    decoration: const BoxDecoration(color: AppColors.cream, shape: BoxShape.circle)),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Update `lib/screens/home_screen.dart`** to match the new callback and drop the SnackBar. Replace the `_updatePlan` method (lines ~35-49) with:

```dart
  Future<void> _updatePlan(WeekPlan newPlan) async {
    await AppStore.savePlan(newPlan);
    setState(() => _plan = newPlan);
    AppStore.writeWidgetData(newPlan, _todayKey).ignore();
  }
```

And in `build`, the `WeekPlanner(...)` call stays `onPlanChanged: _updatePlan` (now type-compatible). No other change in this task.

- [ ] **Step 5: Run the planner tests**

Run: `flutter test test/widgets/week_planner_test.dart`
Expected: PASS (all 4).

- [ ] **Step 6: Analyze + full test run**

Run: `flutter analyze` → Expected: clean.
Run: `flutter test` → Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add daily_command_center/lib/widgets/week_planner.dart daily_command_center/lib/screens/home_screen.dart daily_command_center/test/widgets/week_planner_test.dart
git commit -m "feat: redesign Plan Your Week as one row per day with inline caption"
```

---

## Task 4: Block trackability + signature

**Files:**
- Modify: `lib/data/models.dart:3-19`
- Test: `test/data/models_test.dart`

- [ ] **Step 1: Write the failing tests** — append inside the existing `main()` in `test/data/models_test.dart` (add the import `import 'package:daily_command_center/data/models.dart';` if not already present):

```dart
  group('Block.isTrackable', () {
    test('meal/focus/dsa/train are trackable', () {
      for (final c in ['meal', 'focus', 'dsa', 'train']) {
        expect(Block(time: '8:00', cls: c, label: 'x').isTrackable, isTrue, reason: c);
      }
    });
    test('work/chill are passive', () {
      for (final c in ['work', 'chill']) {
        expect(Block(time: '8:00', cls: c, label: 'x').isTrackable, isFalse, reason: c);
      }
    });
  });

  test('Block.signature combines time and label', () {
    const b = Block(time: '10:00', cls: 'train', label: 'Train — Workout B');
    expect(b.signature, '10:00|Train — Workout B');
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/data/models_test.dart`
Expected: FAIL — `isTrackable`/`signature` not defined.

- [ ] **Step 3: Add the getters** to the `Block` class in `lib/data/models.dart` (after the constructor, before the closing brace):

```dart
  /// Blocks the user actively chooses to do (counted for adherence).
  /// Passive context — the job, commute, chill, wind-down, sleep — is `work`/`chill`.
  bool get isTrackable => cls != 'work' && cls != 'chill';

  /// Stable identity within a day.
  String get signature => '$time|$label';
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/data/models_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/models.dart daily_command_center/test/data/models_test.dart
git commit -m "feat: add Block.isTrackable and Block.signature"
```

---

## Task 5: AdherenceStore (persistence + 7-day read)

**Files:**
- Create: `lib/data/adherence_store.dart`
- Test: `test/data/adherence_store_test.dart`

- [ ] **Step 1: Write the failing tests** — create `test/data/adherence_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/adherence_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('done set round-trips', () async {
    final day = DateTime(2026, 6, 5);
    expect(await AdherenceStore.loadDone(day), isEmpty);
    await AdherenceStore.saveDone(day, {'8:00|Wake', '10:00|Train'});
    expect(await AdherenceStore.loadDone(day), {'8:00|Wake', '10:00|Train'});
  });

  test('last7 returns 7 entries oldest->today, null for missing days', () async {
    final today = DateTime(2026, 6, 5);
    await AdherenceStore.writeAdherence(today, 3, 6);
    final week = await AdherenceStore.last7(today);
    expect(week.length, 7);
    expect(week.last.pct, 50.0); // today
    expect(week.first.pct, isNull); // 6 days ago, no record
  });

  test('weeklyAverage ignores days without data', () async {
    final today = DateTime(2026, 6, 5);
    await AdherenceStore.writeAdherence(today, 4, 4); // 100%
    await AdherenceStore.writeAdherence(today.subtract(const Duration(days: 1)), 1, 2); // 50%
    final week = await AdherenceStore.last7(today);
    expect(AdherenceStore.weeklyAverage(week), 75.0);
  });

  test('zero total yields null pct (no divide by zero)', () async {
    final today = DateTime(2026, 6, 5);
    await AdherenceStore.writeAdherence(today, 0, 0);
    final week = await AdherenceStore.last7(today);
    expect(week.last.pct, isNull);
  });

  test('weeklyAverage of all-empty week is null', () async {
    final week = await AdherenceStore.last7(DateTime(2026, 6, 5));
    expect(AdherenceStore.weeklyAverage(week), isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/data/adherence_store_test.dart`
Expected: FAIL — `adherence_store.dart` does not exist.

- [ ] **Step 3: Create `lib/data/adherence_store.dart`** with this exact content:

```dart
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One day's adherence for the 7-day strip. `pct` is null when no record exists.
class DayAdherence {
  final DateTime day;
  final double? pct;
  const DayAdherence(this.day, this.pct);
}

/// Per-day done-set and adherence summary, persisted in shared_preferences.
/// Keys: `done_<yyyy-MM-dd>` (list of block signatures),
///       `adherence_<yyyy-MM-dd>` ({done, total}).
class AdherenceStore {
  static final DateFormat _fmt = DateFormat('yyyy-MM-dd');
  static String _doneKey(DateTime d) => 'done_${_fmt.format(d)}';
  static String _adhKey(DateTime d) => 'adherence_${_fmt.format(d)}';

  static Future<Set<String>> loadDone(DateTime day) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_doneKey(day));
    if (raw == null) return <String>{};
    try {
      return (jsonDecode(raw) as List).map((e) => e as String).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static Future<void> saveDone(DateTime day, Set<String> done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_doneKey(day), jsonEncode(done.toList()));
  }

  static Future<void> writeAdherence(DateTime day, int done, int total) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adhKey(day), jsonEncode({'done': done, 'total': total}));
  }

  /// Last 7 days, oldest first, ending today. `pct` null where no record.
  static Future<List<DayAdherence>> last7(DateTime today) async {
    final prefs = await SharedPreferences.getInstance();
    final base = DateTime(today.year, today.month, today.day);
    final out = <DayAdherence>[];
    for (int i = 6; i >= 0; i--) {
      final day = base.subtract(Duration(days: i));
      final raw = prefs.getString(_adhKey(day));
      double? pct;
      if (raw != null) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final total = (m['total'] as num).toInt();
          final done = (m['done'] as num).toInt();
          pct = total > 0 ? done / total * 100 : null;
        } catch (_) {
          pct = null;
        }
      }
      out.add(DayAdherence(day, pct));
    }
    return out;
  }

  /// Average of the days that have data; null if none do.
  static double? weeklyAverage(List<DayAdherence> days) {
    final vals = days.where((d) => d.pct != null).map((d) => d.pct!).toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/data/adherence_store_test.dart`
Expected: PASS (all 5).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/adherence_store.dart daily_command_center/test/data/adherence_store_test.dart
git commit -m "feat: add AdherenceStore for done-set and 7-day adherence"
```

---

## Task 6: Today screen (7-day strip + checklist)

A standalone screen taking the plan, today's done-set, and an `onToggle` callback. Compiles independently (home wires it in Task 7).

**Files:**
- Create: `lib/screens/today_screen.dart`
- Test: `test/screens/today_screen_test.dart`

- [ ] **Step 1: Write the failing tests** — create `test/screens/today_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/logic/planner.dart';
import 'package:daily_command_center/screens/today_screen.dart';

Widget _host({required void Function(String) onToggle, Set<String> done = const {}}) =>
    MaterialApp(home: TodayScreen(
      plan: PlannerLogic.defaultWeek(),
      todayKey: 'mon', // office + training in the default week
      doneToday: done,
      onToggle: onToggle,
      debugNow: 10.5, // 10:30 → inside the 10:00 training block
    ));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> settle(WidgetTester t) async {
    // Tall surface so the ListView builds every row (lazy lists skip off-screen rows).
    t.view.physicalSize = const Size(1200, 3000);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await t.pump();
    await t.pump(const Duration(milliseconds: 50)); // resolve last7 future
  }

  testWidgets('renders the week strip header and screen title', (tester) async {
    await tester.pumpWidget(_host(onToggle: (_) {}));
    await settle(tester);
    expect(find.text('LAST 7 DAYS'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('tapping a trackable row reports its signature', (tester) async {
    String? sig;
    await tester.pumpWidget(_host(onToggle: (s) => sig = s));
    await settle(tester);
    await tester.tap(find.text('Wake · water · sunlight'));
    await tester.pump();
    expect(sig, '8:00|Wake · water · sunlight');
  });

  testWidgets('passive block is not tappable', (tester) async {
    var called = false;
    await tester.pumpWidget(_host(onToggle: (_) => called = true));
    await settle(tester);
    await tester.tap(find.text('Walk to office (10 min)'));
    await tester.pump();
    expect(called, isFalse);
  });

  testWidgets('current block shows NOW', (tester) async {
    await tester.pumpWidget(_host(onToggle: (_) {}));
    await settle(tester);
    expect(find.text('NOW'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/screens/today_screen_test.dart`
Expected: FAIL — `today_screen.dart` does not exist.

- [ ] **Step 3: Create `lib/screens/today_screen.dart`** with this exact content:

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/adherence_store.dart';
import '../data/models.dart';
import '../logic/timeline.dart';
import '../main.dart';

const _dayNames = {
  'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday',
  'thu': 'Thursday', 'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
};

class TodayScreen extends StatefulWidget {
  final WeekPlan plan;
  final String todayKey;
  final Set<String> doneToday;
  final void Function(String signature) onToggle;
  final double? debugNow; // test seam; defaults to nowDecimal()

  const TodayScreen({
    super.key,
    required this.plan,
    required this.todayKey,
    required this.doneToday,
    required this.onToggle,
    this.debugNow,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Set<String> _done;
  List<DayAdherence>? _week;

  @override
  void initState() {
    super.initState();
    _done = {...widget.doneToday};
    AdherenceStore.last7(DateTime.now()).then((w) {
      if (mounted) setState(() => _week = w);
    });
  }

  void _toggle(String sig) {
    setState(() => _done.contains(sig) ? _done.remove(sig) : _done.add(sig));
    widget.onToggle(sig);
  }

  @override
  Widget build(BuildContext context) {
    final dayPlan = widget.plan[widget.todayKey]!;
    final blocks = buildTimeline(widget.todayKey, dayPlan);
    final times = buildTimes(blocks);
    final now = widget.debugNow ?? nowDecimal();

    int curIdx = -1;
    for (int i = 0; i < blocks.length; i++) {
      final start = times[i];
      final end = i < blocks.length - 1 ? times[i + 1] : 25.0;
      if (now >= start && now < end) {
        curIdx = i;
        break;
      }
    }

    final trackable = blocks.where((b) => b.isTrackable).toList();
    final total = trackable.length;
    final done = trackable.where((b) => _done.contains(b.signature)).length;
    final dayName = _dayNames[widget.todayKey] ?? widget.todayKey;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.cream,
        title: Text('Today', style: GoogleFonts.fraunces(fontWeight: FontWeight.w800, color: AppColors.cream)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _weekStrip(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${dayName.toUpperCase()} · TODAY',
                  style: const TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.sky, fontWeight: FontWeight.w600)),
              Text('$done of $total followed',
                  style: const TextStyle(fontSize: 11, color: AppColors.moss, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: total > 0 ? done / total : 0,
              backgroundColor: AppColors.panel2,
              color: AppColors.moss,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(blocks.length, (i) => _row(blocks[i], i == curIdx)),
        ],
      ),
    );
  }

  Widget _weekStrip() {
    final week = _week;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LAST 7 DAYS',
                  style: TextStyle(fontSize: 11, letterSpacing: 1, color: AppColors.sky, fontWeight: FontWeight.w600)),
              Text(_weekLabel(week),
                  style: const TextStyle(fontSize: 13, color: AppColors.moss, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 54,
            child: week == null
                ? const Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.moss)))
                : Row(crossAxisAlignment: CrossAxisAlignment.end, children: week.map(_bar).toList()),
          ),
        ],
      ),
    );
  }

  String _weekLabel(List<DayAdherence>? week) {
    if (week == null) return '';
    final avg = AdherenceStore.weeklyAverage(week);
    return avg == null ? 'No data yet' : '${avg.round()}% followed';
  }

  Widget _bar(DayAdherence d) {
    final pct = d.pct;
    final h = pct == null ? 8.0 : 8 + pct / 100 * 36;
    final color = pct == null ? AppColors.line : (pct >= 60 ? AppColors.moss : AppColors.amber);
    final letter = DateFormat('E').format(d.day)[0];
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(height: h, margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 4),
          Text(letter, style: const TextStyle(fontSize: 9, color: AppColors.dim)),
        ],
      ),
    );
  }

  Widget _row(Block b, bool isCurrent) {
    if (!b.isTrackable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Opacity(
          opacity: 0.45,
          child: Row(children: [
            const SizedBox(width: 22, child: Text('·', textAlign: TextAlign.center, style: TextStyle(color: AppColors.dim))),
            const SizedBox(width: 10),
            SizedBox(width: 42, child: Text(b.time, style: const TextStyle(fontSize: 11, color: AppColors.dim))),
            Expanded(child: Text(b.label, style: const TextStyle(fontSize: 13, color: AppColors.muted))),
          ]),
        ),
      );
    }
    final isDone = _done.contains(b.signature);
    return GestureDetector(
      onTap: () => _toggle(b.signature),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: EdgeInsets.symmetric(vertical: 7, horizontal: isCurrent ? 8 : 0),
        decoration: isCurrent
            ? BoxDecoration(color: AppColors.panel, border: Border.all(color: AppColors.terra), borderRadius: BorderRadius.circular(10))
            : null,
        child: Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isDone ? AppColors.moss : Colors.transparent,
              border: Border.all(color: isDone ? AppColors.moss : (isCurrent ? AppColors.terra : AppColors.dim), width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: isDone ? const Icon(Icons.check, size: 15, color: AppColors.bg) : null,
          ),
          const SizedBox(width: 10),
          SizedBox(width: 42, child: Text(b.time,
              style: TextStyle(fontSize: 11, color: isCurrent ? AppColors.terra : AppColors.dim, fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400))),
          Expanded(child: Text(b.label,
              style: TextStyle(
                fontSize: 13.5,
                color: isDone ? AppColors.muted : AppColors.cream,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                decoration: isDone ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.muted,
              ))),
          if (isCurrent) const Text('NOW', style: TextStyle(fontSize: 9, color: AppColors.terra, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/screens/today_screen_test.dart`
Expected: PASS (all 4).

- [ ] **Step 5: Analyze + commit**

Run: `flutter analyze` → clean.
```bash
git add daily_command_center/lib/screens/today_screen.dart daily_command_center/test/screens/today_screen_test.dart
git commit -m "feat: add Today screen with 7-day strip and checklist"
```

---

## Task 7: Live card done-state + home wiring

Gives `NowCard` the new API (done/green state, View all, Mark done) and wires `home_screen` to own `_doneToday`, record adherence, and navigate to the Today screen.

**Files:**
- Modify (rewrite): `lib/widgets/now_card.dart`
- Modify (rewrite): `lib/screens/home_screen.dart`
- Test (rewrite): `test/widgets/now_card_test.dart`

- [ ] **Step 1: Read the current `test/widgets/now_card_test.dart`** to see how it constructs `NowCard` (its API is changing).

Run: `cat test/widgets/now_card_test.dart`

- [ ] **Step 2: Write the failing tests** — replace the entire contents of `test/widgets/now_card_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/models.dart';
import 'package:daily_command_center/logic/planner.dart';
import 'package:daily_command_center/logic/timeline.dart';
import 'package:daily_command_center/widgets/now_card.dart';

WeekPlan get _plan => PlannerLogic.defaultWeek(); // mon = office + training

Widget _host({
  required Set<String> done,
  required double now,
  void Function(String)? onToggle,
  VoidCallback? onViewAll,
}) =>
    MaterialApp(home: Scaffold(body: NowCard(
      plan: _plan,
      todayKey: 'mon',
      doneToday: done,
      debugNow: now,
      onViewAll: onViewAll ?? () {},
      onToggleDone: onToggle ?? (_) {},
    )));

void main() {
  // 10:30 falls inside mon's 10:00 training block (trackable).
  testWidgets('shows Mark done for a trackable current block', (tester) async {
    await tester.pumpWidget(_host(done: const {}, now: 10.5));
    expect(find.text('◯ Mark done'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('done current block shows green Done + badge', (tester) async {
    final train = buildTimeline('mon', _plan['mon']!).firstWhere((b) => b.isTrain);
    await tester.pumpWidget(_host(done: {train.signature}, now: 10.5));
    expect(find.text('✓ Done'), findsOneWidget);
    expect(find.text('✓ done'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tapping Mark done reports the current block signature', (tester) async {
    final train = buildTimeline('mon', _plan['mon']!).firstWhere((b) => b.isTrain);
    String? toggled;
    await tester.pumpWidget(_host(done: const {}, now: 10.5, onToggle: (s) => toggled = s));
    await tester.tap(find.text('◯ Mark done'));
    await tester.pump();
    expect(toggled, train.signature);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('passive current block hides Mark done', (tester) async {
    // 14.5 = 2:30pm = "Work — 2:00 to 8:00" (cls work, passive)
    await tester.pumpWidget(_host(done: const {}, now: 14.5));
    expect(find.text('◯ Mark done'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('View all is always present and reports taps', (tester) async {
    var tapped = false;
    await tester.pumpWidget(_host(done: const {}, now: 14.5, onViewAll: () => tapped = true));
    await tester.tap(find.text('View all ›'));
    await tester.pump();
    expect(tapped, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/widgets/now_card_test.dart`
Expected: FAIL (compile error — `NowCard` still uses the old `onTap` API).

- [ ] **Step 4: Rewrite `lib/widgets/now_card.dart`** with this exact content:

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
  final Set<String> doneToday;
  final VoidCallback onViewAll;
  final void Function(String signature) onToggleDone;
  final double? debugNow; // test seam; defaults to nowDecimal()

  const NowCard({
    super.key,
    required this.plan,
    required this.todayKey,
    required this.doneToday,
    required this.onViewAll,
    required this.onToggleDone,
    this.debugNow,
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
    final dayPlan = widget.plan[widget.todayKey];
    if (dayPlan == null) return const SizedBox.shrink();

    final blocks = buildTimeline(widget.todayKey, dayPlan);
    final times = buildTimes(blocks);
    final now = widget.debugNow ?? nowDecimal();

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

    final trackableCur = (cur != null && cur.isTrackable) ? cur : null;
    final isDone = trackableCur != null && widget.doneToday.contains(trackableCur.signature);
    final isWorkout = cur?.isTrain ?? false;

    final String title;
    final String desc;
    Color gradStart;
    Color gradEnd;

    if (now < times.first) {
      title = 'Still resting';
      desc = 'Day kicks off at 8:00 with wake + sunlight.';
      gradStart = const Color(0xFF2A3530);
      gradEnd = const Color(0xFF1F2925);
    } else if (cur == null) {
      title = 'Wind down';
      desc = "Day's done — sleep is the priority now.";
      gradStart = const Color(0xFF2A3530);
      gradEnd = const Color(0xFF1F2925);
    } else {
      title = cur.label;
      desc = cur.desc;
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
    if (isDone) {
      gradStart = const Color(0xFF4F7A3C);
      gradEnd = const Color(0xFF3C5E2D);
    }

    final nextLine = next != null ? 'Next · ${next.time} — ${next.label}' : '';
    final dayName = _dayNames[widget.todayKey] ?? widget.todayKey;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [gradStart, gradEnd]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: gradStart.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(width: 140, height: 140,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Right now · $dayName',
                        style: const TextStyle(fontSize: 11, letterSpacing: 2, color: Colors.white70, fontWeight: FontWeight.w600)),
                    GestureDetector(
                      onTap: widget.onViewAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                        child: const Text('View all ›', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(title,
                        style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.05))),
                    if (isDone)
                      Container(
                        margin: const EdgeInsets.only(left: 8, top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                        child: const Text('✓ done', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 13.5, color: Colors.white70)),
                ],
                if (nextLine.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Divider(color: Colors.white.withValues(alpha: 0.2), height: 1),
                  const SizedBox(height: 8),
                  Text(nextLine, style: const TextStyle(fontSize: 12.5, color: Colors.white60)),
                ],
                if (isWorkout) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
                    child: const Text('View Workout →',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
                if (trackableCur != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => widget.onToggleDone(trackableCur.signature),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDone ? AppColors.cream : Colors.white.withValues(alpha: 0.18),
                        border: isDone ? null : Border.all(color: Colors.white.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(isDone ? '✓ Done' : '◯ Mark done',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: isDone ? const Color(0xFF3C5E2D) : Colors.white)),
                    ),
                  ),
                ],
                if (progressPct > 0 && !isDone) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressPct / 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
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
    );
  }
}
```

- [ ] **Step 5: Run the now_card tests**

Run: `flutter test test/widgets/now_card_test.dart`
Expected: PASS (all 5).

- [ ] **Step 6: Rewrite `lib/screens/home_screen.dart`** with this exact content (adds `_doneToday`, adherence recording, navigation):

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../data/adherence_store.dart';
import '../logic/timeline.dart';
import '../main.dart';
import '../widgets/now_card.dart';
import '../widgets/week_planner.dart';
import 'today_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  WeekPlan? _plan;
  Set<String> _doneToday = {};
  static const _days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
  late String _todayKey;

  @override
  void initState() {
    super.initState();
    _todayKey = _days[DateTime.now().weekday % 7];
    _load();
  }

  Future<void> _load() async {
    final plan = await AppStore.loadPlan();
    final done = await AdherenceStore.loadDone(DateTime.now());
    if (!mounted) return; // widget disposed mid-load (e.g. in tests)
    setState(() {
      _plan = plan;
      _doneToday = done;
    });
    AppStore.writeWidgetData(plan, _todayKey).ignore();
    _recordAdherence(plan, done);
  }

  ({int done, int total}) _tally(WeekPlan plan, Set<String> done) {
    final dp = plan[_todayKey];
    if (dp == null) return (done: 0, total: 0);
    final trackable = buildTimeline(_todayKey, dp).where((b) => b.isTrackable).toList();
    return (
      done: trackable.where((b) => done.contains(b.signature)).length,
      total: trackable.length,
    );
  }

  void _recordAdherence(WeekPlan plan, Set<String> done) {
    final t = _tally(plan, done);
    AdherenceStore.writeAdherence(DateTime.now(), t.done, t.total).ignore();
  }

  Future<void> _updatePlan(WeekPlan newPlan) async {
    await AppStore.savePlan(newPlan);
    setState(() => _plan = newPlan);
    AppStore.writeWidgetData(newPlan, _todayKey).ignore();
    _recordAdherence(newPlan, _doneToday);
  }

  Future<void> _toggleDone(String signature) async {
    final next = {..._doneToday};
    next.contains(signature) ? next.remove(signature) : next.add(signature);
    setState(() => _doneToday = next);
    await AdherenceStore.saveDone(DateTime.now(), next);
    if (_plan != null) _recordAdherence(_plan!, next);
  }

  void _openToday() {
    final plan = _plan;
    if (plan == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TodayScreen(
        plan: plan,
        todayKey: _todayKey,
        doneToday: _doneToday,
        onToggle: _toggleDone,
      ),
    ));
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
                    doneToday: _doneToday,
                    onViewAll: _openToday,
                    onToggleDone: _toggleDone,
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
          const Text('CYRUS · DAILY COMMAND CENTER',
              style: TextStyle(fontSize: 10, letterSpacing: 3, color: AppColors.terra, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Run The Day.',
              style: GoogleFonts.fraunces(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.cream, height: 0.95, letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text('Lean & defined — not big. Plan it, then run it.',
              style: GoogleFonts.fraunces(fontSize: 15, fontStyle: FontStyle.italic, color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(dateStr, style: const TextStyle(fontSize: 13, color: AppColors.moss, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 7: Analyze + full test run**

Run: `flutter analyze` → Expected: clean.
Run: `flutter test` → Expected: all pass (models, planner, timeline, workouts, adherence_store, week_planner, now_card, today_screen, widget_test).

- [ ] **Step 8: Commit**

```bash
git add daily_command_center/lib/widgets/now_card.dart daily_command_center/lib/screens/home_screen.dart daily_command_center/test/widgets/now_card_test.dart
git commit -m "feat: live card done-state + View all link + adherence wiring"
```

---

## Manual verification (after all tasks)

Run the app on the phone (see `docs/CONTINUE.md` → "How to run"):

```powershell
flutter run
```

Check:
1. Launcher shows **Reminders 2** with the terracotta check icon (uninstall/reinstall if the old icon is cached).
2. Live card during a trackable block shows **◯ Mark done**; tapping it turns the card **green** with **✓ Done**; the count it feeds updates.
3. During the job/commute/chill, **Mark done** is absent.
4. **View all ›** opens the Today screen; passive rows are faded and uncheckable; current row shows **NOW**; the header count and 7-day strip render.
5. Ticking on the Today screen and on the live card stay in sync; reopening the app the same day keeps the ticks.
6. "Plan Your Week" rows have large schedule chips + a 48px train/rest switch; turning on a 5th training day shows a sky-colored caption under the grid (no toast).

---

## Self-review notes

- **Spec coverage:** Rebrand (T1), icon (T2), planner redesign + inline caption (T3), trackable rule (T4), AdherenceStore + 7-day (T5), Today screen (T6), live card done/green + View all + home wiring (T7). All spec sections mapped.
- **Out of scope honored:** no widget changes, no workout logger.
- **Type consistency:** `Block.isTrackable`/`signature`, `AdherenceStore.{loadDone,saveDone,writeAdherence,last7,weeklyAverage}`, `DayAdherence(day,pct)`, `NowCard`/`TodayScreen` `debugNow` seam, `WeekPlanner.onPlanChanged: void Function(WeekPlan)` — consistent across tasks.
