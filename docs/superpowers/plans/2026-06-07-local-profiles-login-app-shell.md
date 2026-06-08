# Local Profiles, Login & App Shell — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a local, on-device multi-profile layer to the Reminders 2 app: a login screen that is a profile picker (no backend), a per-profile data namespace, an onboarding stub for new profiles, a navigation drawer (side panel) that splits the app into focused screens, Settings, and logout — all visually polished.

**Architecture:** A `ProfileScope` prepends the active profile's id to every persisted data key, so the existing/​v3 stores (`AppStore`, `StateStore`, `AdherenceStore`, logs) become per-profile by routing their key construction through it — no store rewrite. A `ProfileRepository` manages the profile index, the active pointer, and create/delete/export/import. A root `AuthGate` chooses `LoginScreen` (picker) vs `AppShell` (Scaffold + Drawer). New profiles run an onboarding stub that clones the bundled seed `Plan` and sets the week shape. The "one file per profile" idea from the spec becomes export/import backup, not the live backing.

**Tech Stack:** Flutter/Dart, `shared_preferences`, `google_fonts`, `intl`. No new packages required.

---

## Reference docs (read before starting)

- This feature's design spec: [`../specs/2026-06-07-local-profiles-login-app-shell-design.md`](../specs/2026-06-07-local-profiles-login-app-shell-design.md)
- Decisions: **ADR-018** (login = local profile picker) and **ADR-019** (per-profile key prefix; revised by this plan) in [`../../DECISIONS.md`](../../DECISIONS.md)
- Status: [`../../CONTINUE.md`](../../CONTINUE.md)

---

## Preconditions — execute AFTER the v3 core

This plan is **sequenced after** the v3 drift-engine plan ([`2026-06-07-life-json-v3-drift-engine.md`](2026-06-07-life-json-v3-drift-engine.md)), at minimum its storage layer (Phases A–B). It binds to these post-v3 APIs — confirm they exist before starting; if v3 shipped differently, adjust the integration tasks (P0-3) accordingly:

| Symbol | Where | Used by |
|---|---|---|
| `AppStore.loadPlan() → Future<Plan>`, `AppStore.savePlan(Plan)` | `lib/data/store.dart` | P0-3, P3, P5 |
| `AppStore` keys `'activePlan'`, `'log_<id>'` | `lib/data/store.dart` | P0-3 |
| `AppStore.loadLogs(id)` / `saveLogs(id, logs)` | `lib/data/store.dart` | P5 |
| `StateStore` key `'state_<yyyy-MM-dd>'` (`loadState`/`saveState`) | `lib/data/state_store.dart` | P0-3, P5 |
| `AdherenceStore` keys `'done_<date>'`, `'adherence_<date>'` | `lib/data/adherence_store.dart` | P0-3, P5 |
| `Plan` model + `Plan.copyWith(week:)`, `WeekEntry` | `lib/data/models.dart` | P3 |
| `HomeScreen`, `TodayScreen`, `WeekPlanner` take a `Plan` | `lib/screens/`, `lib/widgets/` | P4 |
| Bundled asset `assets/seed_plan.json` | `assets/` | P3, P5 |

**Global (NON-prefixed) keys** that must never be routed through `ProfileScope`: `activeProfileId`, `profileIndex` (managed by `ProfileRepository`), and the `flutter.*` widget keys (read by `NowWidgetProvider.kt` for whoever is logged in).

---

## Storage decision (revises ADR-019)

The spec originally chose one JSON file per profile. After reading the v3 plan (all stores are SharedPreferences-key based, and v3 adds `state_store.dart`), file-backing would force v3's stores to be re-plumbed — duplicate work. **Decision:** isolate profiles with a **per-profile key prefix** (`p_<id>__<base>`) applied centrally in `ProfileScope`; every store keeps using SharedPreferences. v3's keys get namespaced for free. The JSON "file per profile" survives as **export/import** (gather every `p_<id>__*` key → one JSON blob the user can copy out / paste back). Update ADR-019 + the spec §3 to match (done alongside this plan).

---

## File structure (what each file owns)

**Created**

| File | Responsibility |
|---|---|
| `daily_command_center/lib/data/profile_scope.dart` | `ProfileScope` — holds the active profile id; `key(base)` prefixes data keys. |
| `daily_command_center/lib/data/profile_repository.dart` | `ProfileMeta`, `ProfileRepository` — index, active pointer, create/list/delete/export/import, first-run seed/migration. |
| `daily_command_center/lib/screens/auth_gate.dart` | `AuthGate` — root widget: routes to LoginScreen vs AppShell. |
| `daily_command_center/lib/screens/login_screen.dart` | `LoginScreen` — profile picker + "new profile" entry. |
| `daily_command_center/lib/screens/onboarding_screen.dart` | `OnboardingScreen` — stub flow → builds a cloned `Plan` for a new profile. |
| `daily_command_center/lib/screens/app_shell.dart` | `AppShell` — Scaffold + Drawer + section switcher. |
| `daily_command_center/lib/screens/settings_screen.dart` | `SettingsScreen` — profile, delete, export/import, reset, clear history, about. |
| `daily_command_center/lib/widgets/coming_soon.dart` | `ComingSoon` — one reusable placeholder body. |
| `daily_command_center/lib/widgets/today_view.dart` | `TodayView` — HomeScreen's dashboard body, extracted to live inside AppShell. |
| `daily_command_center/test/...` | One test file per unit (see tasks). |

**Modified**

| File | Change |
|---|---|
| `lib/data/store.dart` | Route `activePlan` + `log_<id>` keys through `ProfileScope.key(...)`. |
| `lib/data/state_store.dart` | Route `state_<date>` key through `ProfileScope.key(...)`. |
| `lib/data/adherence_store.dart` | Route `done_<date>` + `adherence_<date>` keys through `ProfileScope.key(...)`. |
| `lib/main.dart` | `home:` → `AuthGate`; init `ProfileScope` from the saved active id at startup. |
| `lib/screens/home_screen.dart` | Extract dashboard body into `TodayView`; `HomeScreen` becomes a thin wrapper (kept for tests) or is folded into AppShell. |

---

## Conventions for every task

- **TDD:** failing test → run (confirm fail) → minimal implementation → run (confirm pass) → commit.
- **Run tests** from `daily_command_center/`: `flutter test test/path/file.dart` (single) or `flutter test` (all).
- **Profile-aware tests** must set the scope in `setUp`: `SharedPreferences.setMockInitialValues({}); ProfileScope.setActive('test');` and reset with `ProfileScope.setActive(null);` in `tearDown`.
- **Commit** after each green task with the message shown.
- **Visual polish is a requirement** (spec §7): reuse `AppColors` + Fraunces/Spline Sans; no second visual language. Phase 6 is a dedicated polish pass, but build each screen tastefully as you go.

---

## Phase 0 — Per-profile storage namespace

> Outcome: every persisted data key is silently prefixed by the active profile; with a single active profile the app behaves exactly as before (regression tests green).

### Task P0-1: `ProfileScope` (active id + key prefixer)

**Files:**
- Create: `daily_command_center/lib/data/profile_scope.dart`
- Test: `daily_command_center/test/data/profile_scope_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/profile_scope.dart';

void main() {
  tearDown(() => ProfileScope.setActive(null));

  test('no active profile → key passes through unchanged', () {
    ProfileScope.setActive(null);
    expect(ProfileScope.activeId, isNull);
    expect(ProfileScope.key('activePlan'), 'activePlan');
  });

  test('active profile → key is prefixed', () {
    ProfileScope.setActive('cyrus');
    expect(ProfileScope.activeId, 'cyrus');
    expect(ProfileScope.key('activePlan'), 'p_cyrus__activePlan');
    expect(ProfileScope.key('log_A'), 'p_cyrus__log_A');
  });

  test('prefix detects whether a raw key belongs to a profile', () {
    expect(ProfileScope.prefixFor('cyrus'), 'p_cyrus__');
    expect(ProfileScope.isProfileKey('p_cyrus__log_A'), true);
    expect(ProfileScope.isProfileKey('flutter.currentAction'), false);
    expect(ProfileScope.isProfileKey('activeProfileId'), false);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_scope_test.dart`
Expected: FAIL — `ProfileScope` not defined.

- [ ] **Step 3: Implement `profile_scope.dart`**

```dart
/// Holds the active profile id and namespaces persisted *data* keys.
///
/// Global keys (`activeProfileId`, `profileIndex`, `flutter.*` widget keys) are
/// NEVER routed through here — only the stores' data keys are.
class ProfileScope {
  static String? _activeId;

  static String? get activeId => _activeId;

  /// Set the logged-in profile (or null when logged out). Call this before any
  /// store access — `AuthGate` and `ProfileRepository.setActive` do so.
  static void setActive(String? id) => _activeId = id;

  static String prefixFor(String id) => 'p_${id}__';

  /// Prefix a store's base key with the active profile. With no active profile
  /// the key is returned unchanged (used only during first-run migration).
  static String key(String base) {
    final id = _activeId;
    return id == null ? base : '${prefixFor(id)}$base';
  }

  /// True if [rawKey] is any profile-scoped data key (`p_<id>__...`).
  static bool isProfileKey(String rawKey) => rawKey.startsWith('p_') && rawKey.contains('__');
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_scope_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_scope.dart daily_command_center/test/data/profile_scope_test.dart
git commit -m "feat(profiles): add ProfileScope key prefixer"
```

### Task P0-2: Wire `main.dart` startup to set the scope

**Files:**
- Modify: `daily_command_center/lib/main.dart`

This is a small, non-TDD wiring step (UI entry; covered by AuthGate tests in P2). It ensures the scope is set from the saved active id before the first frame.

- [ ] **Step 1: Update `main()`** in `lib/main.dart` to set the scope from storage before `runApp`, and point `home:` at `AuthGate` (the widget arrives in P2 — until then this step will not compile; do P2 in the same branch or temporarily keep `home: const HomeScreen()`).

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'data/profile_repository.dart';
import 'screens/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProfileRepository.restoreActive(); // sets ProfileScope from saved activeProfileId
  runApp(const DailyCommandCenterApp());
}
```

And change the `MaterialApp`:

```dart
      home: const AuthGate(),
```

- [ ] **Step 2: Commit** (after P1/P2 land so it compiles)

```bash
git add daily_command_center/lib/main.dart
git commit -m "feat(profiles): restore active profile scope at startup; route home to AuthGate"
```

### Task P0-3: Route store keys through `ProfileScope`

**Files:**
- Modify: `daily_command_center/lib/data/store.dart`
- Modify: `daily_command_center/lib/data/state_store.dart`
- Modify: `daily_command_center/lib/data/adherence_store.dart`
- Test: `daily_command_center/test/data/profile_isolation_test.dart`

- [ ] **Step 1: Write the failing test** (proves two profiles don't bleed)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ProfileScope.setActive(null));

  test('logs written under one profile are invisible to another', () async {
    ProfileScope.setActive('cyrus');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '10')]);

    ProfileScope.setActive('alex');
    expect(await AppStore.loadLogs('A'), isEmpty);

    ProfileScope.setActive('cyrus');
    final logs = await AppStore.loadLogs('A');
    expect(logs.single.reps, '10');
  });

  test('each profile seeds and edits its own plan independently', () async {
    ProfileScope.setActive('cyrus');
    final p1 = await AppStore.loadPlan();
    expect(p1.schemaVersion, 3);

    ProfileScope.setActive('alex');
    final p2 = await AppStore.loadPlan(); // fresh seed for alex
    expect(p2.week['mon']!.templateId, 'office');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_isolation_test.dart`
Expected: FAIL — keys are not yet prefixed, so `alex` sees `cyrus`'s log.

- [ ] **Step 3: Route the keys.** In each store, wrap the key strings with `ProfileScope.key(...)`. Concretely:

`store.dart` — add `import 'profile_scope.dart';`, then change key construction:

```dart
  // was: final raw = prefs.getString(_planKey);
  final raw = prefs.getString(ProfileScope.key(_planKey));
  // was: await prefs.setString(_planKey, jsonEncode(plan.toJson()));
  await prefs.setString(ProfileScope.key(_planKey), jsonEncode(plan.toJson()));
  // was: prefs.getString('$_logPrefix$workoutKey');
  prefs.getString(ProfileScope.key('$_logPrefix$workoutKey'));
  // was: await prefs.setString('$_logPrefix$workoutKey', ...);
  await prefs.setString(ProfileScope.key('$_logPrefix$workoutKey'), jsonEncode(logs.map((e) => e.toJson()).toList()));
```

`state_store.dart` — add the import, then:

```dart
  static String _key(DateTime d) => ProfileScope.key('state_${_fmt.format(d)}');
  // and in saveState:
  await prefs.setString(ProfileScope.key('state_${state.date}'), jsonEncode(state.toJson()));
```

`adherence_store.dart` — add the import, then:

```dart
  static String _doneKey(DateTime d) => ProfileScope.key('done_${_fmt.format(d)}');
  static String _adhKey(DateTime d)  => ProfileScope.key('adherence_${_fmt.format(d)}');
```

> Leave the `flutter.*` widget keys in `writeWidgetData` untouched — they stay global so the widget shows the active profile's now-state.

- [ ] **Step 4: Run to verify it passes** — and run the full suite to confirm no regression (single active profile behaves as before).

Run: `flutter test test/data/profile_isolation_test.dart` → PASS
Run: `flutter test` → all green (existing store/adherence/timeline tests unaffected, since they run with a single scope).

> If any pre-existing store/adherence test sets values with no active profile and reads them back, it still passes (null scope = pass-through keys).

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/store.dart daily_command_center/lib/data/state_store.dart daily_command_center/lib/data/adherence_store.dart daily_command_center/test/data/profile_isolation_test.dart
git commit -m "feat(profiles): namespace store keys by active profile"
```

---

## Phase 1 — Profile registry

### Task P1-1: `ProfileMeta` + index round-trip

**Files:**
- Create: `daily_command_center/lib/data/profile_repository.dart`
- Test: `daily_command_center/test/data/profile_meta_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/profile_repository.dart';

void main() {
  test('ProfileMeta round-trips through json', () {
    const m = ProfileMeta(id: 'cyrus', displayName: 'Cyrus', archetype: 'Recomp + career switch');
    final round = ProfileMeta.fromJson(m.toJson());
    expect(round.id, 'cyrus');
    expect(round.displayName, 'Cyrus');
    expect(round.archetype, 'Recomp + career switch');
  });

  test('idFor normalizes display names', () {
    expect(ProfileRepository.idFor('  Cyrus '), 'cyrus');
    expect(ProfileRepository.idFor('Alex P'), 'alex_p');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_meta_test.dart`
Expected: FAIL — types not defined.

- [ ] **Step 3: Start `profile_repository.dart`** with the model + id helper (repository methods follow in P1-2).

```dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'profile_scope.dart';

class ProfileMeta {
  final String id;
  final String displayName;
  final String archetype;
  const ProfileMeta({required this.id, required this.displayName, this.archetype = ''});

  factory ProfileMeta.fromJson(Map<String, dynamic> j) => ProfileMeta(
        id: j['id'] as String,
        displayName: j['displayName'] as String,
        archetype: (j['archetype'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'displayName': displayName, 'archetype': archetype};
}

class ProfileRepository {
  static const _activeKey = 'activeProfileId';
  static const _indexKey = 'profileIndex';

  /// Lower-cased, trimmed, spaces→underscores. Used as the storage prefix id.
  static String idFor(String displayName) =>
      displayName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');

  // ── index + active pointer (P1-2) ──────────────────────────────────────────
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_meta_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_meta_test.dart
git commit -m "feat(profiles): ProfileMeta + id normalization"
```

### Task P1-2: Repository — list / create / setActive / restore / delete

**Files:**
- Modify: `daily_command_center/lib/data/profile_repository.dart`
- Test: `daily_command_center/test/data/profile_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ProfileScope.setActive(null));

  test('create adds to index, sets active + scope, and exists()', () async {
    final m = await ProfileRepository.create('Cyrus', archetype: 'Recomp');
    expect(m.id, 'cyrus');
    expect(ProfileScope.activeId, 'cyrus');
    expect(await ProfileRepository.exists('cyrus'), true);
    final list = await ProfileRepository.listProfiles();
    expect(list.single.displayName, 'Cyrus');
  });

  test('restoreActive re-applies the saved scope', () async {
    await ProfileRepository.create('Cyrus');
    ProfileScope.setActive(null);
    await ProfileRepository.restoreActive();
    expect(ProfileScope.activeId, 'cyrus');
  });

  test('delete removes index entry, all data keys, and clears active if current', () async {
    await ProfileRepository.create('Cyrus');
    await AppStore.savePlan(await AppStore.loadPlan()); // writes p_cyrus__activePlan
    await ProfileRepository.delete('cyrus');
    expect(await ProfileRepository.exists('cyrus'), false);
    expect(await ProfileRepository.activeId(), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().where((k) => k.startsWith('p_cyrus__')), isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_repository_test.dart`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Add the repository methods** (inside `ProfileRepository`)

```dart
  static Future<List<ProfileMeta>> listProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ProfileMeta.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveIndex(List<ProfileMeta> metas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(metas.map((e) => e.toJson()).toList()));
  }

  static Future<bool> exists(String id) async =>
      (await listProfiles()).any((m) => m.id == id);

  static Future<String?> activeId() async =>
      (await SharedPreferences.getInstance()).getString(_activeKey);

  /// Re-apply the persisted active profile to [ProfileScope] (call at startup).
  static Future<void> restoreActive() async => ProfileScope.setActive(await activeId());

  static Future<void> setActive(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_activeKey);
    } else {
      await prefs.setString(_activeKey, id);
    }
    ProfileScope.setActive(id);
  }

  /// Create a profile, add it to the index, and make it active. Does NOT seed a
  /// plan — the caller (onboarding) builds one, or the first `AppStore.loadPlan`
  /// under the new scope seeds from the asset.
  static Future<ProfileMeta> create(String displayName, {String archetype = ''}) async {
    final meta = ProfileMeta(id: idFor(displayName), displayName: displayName.trim(), archetype: archetype);
    final metas = await listProfiles();
    if (!metas.any((m) => m.id == meta.id)) {
      await _saveIndex([...metas, meta]);
    }
    await setActive(meta.id);
    return meta;
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(ProfileScope.prefixFor(id))).toList()) {
      await prefs.remove(k);
    }
    await _saveIndex((await listProfiles()).where((m) => m.id != id).toList());
    if (await activeId() == id) await setActive(null);
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_repository_test.dart
git commit -m "feat(profiles): repository list/create/setActive/restore/delete"
```

### Task P1-3: First-run seed + legacy migration of `cyrus`

**Files:**
- Modify: `daily_command_center/lib/data/profile_repository.dart`
- Test: `daily_command_center/test/data/profile_firstrun_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ProfileScope.setActive(null));

  test('fresh install → creates cyrus and makes it active', () async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.ensureFirstRun();
    expect(await ProfileRepository.exists('cyrus'), true);
    expect(ProfileScope.activeId, 'cyrus');
  });

  test('legacy unprefixed data is migrated under cyrus', () async {
    SharedPreferences.setMockInitialValues({
      'activePlan': '{"schemaVersion":3}',
      'log_A': '[]',
      'flutter.currentAction': 'Focus', // global — must NOT move
    });
    await ProfileRepository.ensureFirstRun();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('p_cyrus__activePlan'), '{"schemaVersion":3}');
    expect(prefs.getString('activePlan'), isNull);          // moved
    expect(prefs.getString('flutter.currentAction'), 'Focus'); // untouched
  });

  test('idempotent — running twice keeps a single cyrus', () async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.ensureFirstRun();
    await ProfileRepository.ensureFirstRun();
    expect((await ProfileRepository.listProfiles()).length, 1);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_firstrun_test.dart`
Expected: FAIL — `ensureFirstRun` not defined.

- [ ] **Step 3: Add `ensureFirstRun`** (inside `ProfileRepository`)

```dart
  static const _globalKeys = {_activeKey, _indexKey};

  /// Called once at startup (before AuthGate). If no profiles exist, create
  /// `cyrus` and migrate any legacy unprefixed data into its namespace.
  static Future<void> ensureFirstRun() async {
    if ((await listProfiles()).isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();

    // Move legacy data keys (not global, not a widget key, not already prefixed)
    // into the cyrus namespace.
    const cyrusPrefix = 'p_cyrus__';
    for (final k in prefs.getKeys().toList()) {
      final isGlobal = _globalKeys.contains(k) || k.startsWith('flutter.');
      if (isGlobal || ProfileScope.isProfileKey(k)) continue;
      final v = prefs.get(k);
      if (v is String) {
        await prefs.setString('$cyrusPrefix$k', v);
        await prefs.remove(k);
      }
    }

    await _saveIndex(const [ProfileMeta(id: 'cyrus', displayName: 'Cyrus', archetype: 'Recomp + career switch')]);
    await setActive('cyrus');
    // Note: if there was no legacy plan, the first AppStore.loadPlan under the
    // cyrus scope seeds from assets/seed_plan.json automatically.
  }
```

Also call it from startup — update `main()` (P0-2) to `await ProfileRepository.ensureFirstRun();` **before** `restoreActive()`:

```dart
  await ProfileRepository.ensureFirstRun();
  await ProfileRepository.restoreActive();
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_firstrun_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/lib/main.dart daily_command_center/test/data/profile_firstrun_test.dart
git commit -m "feat(profiles): first-run cyrus seed + legacy migration"
```

### Task P1-4: Export / import a profile

**Files:**
- Modify: `daily_command_center/lib/data/profile_repository.dart`
- Test: `daily_command_center/test/data/profile_export_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ProfileScope.setActive(null));

  test('export then import restores a profile losslessly', () async {
    await ProfileRepository.create('Cyrus', archetype: 'Recomp');
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '12')]);
    final blob = await ProfileRepository.exportProfile('cyrus');

    // Wipe everything, then import into a fresh store.
    SharedPreferences.setMockInitialValues({});
    final meta = await ProfileRepository.importProfile(blob);
    expect(meta.id, 'cyrus');
    expect(await ProfileRepository.exists('cyrus'), true);

    ProfileScope.setActive('cyrus');
    expect((await AppStore.loadLogs('A')).single.reps, '12');
  });

  test('exported blob is valid JSON with meta + data', () async {
    await ProfileRepository.create('Cyrus');
    final blob = await ProfileRepository.exportProfile('cyrus');
    final decoded = jsonDecode(blob) as Map<String, dynamic>;
    expect(decoded['meta']['id'], 'cyrus');
    expect(decoded['data'], isA<Map>());
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_export_test.dart`
Expected: FAIL — methods not defined.

- [ ] **Step 3: Add export/import** (inside `ProfileRepository`)

```dart
  /// Serialize a profile to a portable JSON blob: its meta + every `p_<id>__*`
  /// key (with the prefix stripped so import can re-key cleanly).
  static Future<String> exportProfile(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final meta = (await listProfiles()).firstWhere((m) => m.id == id);
    final prefix = ProfileScope.prefixFor(id);
    final data = <String, String>{};
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) {
      final v = prefs.get(k);
      if (v is String) data[k.substring(prefix.length)] = v;
    }
    return jsonEncode({'meta': meta.toJson(), 'data': data});
  }

  /// Recreate a profile from an exported blob. If the id already exists it is
  /// overwritten. Returns the imported meta.
  static Future<ProfileMeta> importProfile(String blob) async {
    final decoded = jsonDecode(blob) as Map<String, dynamic>;
    final meta = ProfileMeta.fromJson(decoded['meta'] as Map<String, dynamic>);
    final data = (decoded['data'] as Map<String, dynamic>);
    final prefs = await SharedPreferences.getInstance();
    final prefix = ProfileScope.prefixFor(meta.id);
    for (final entry in data.entries) {
      await prefs.setString('$prefix${entry.key}', entry.value as String);
    }
    final metas = await listProfiles();
    final without = metas.where((m) => m.id != meta.id).toList();
    await _saveIndex([...without, meta]);
    return meta;
  }
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_export_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_export_test.dart
git commit -m "feat(profiles): profile export/import"
```

---

## Phase 2 — Auth gate + login screen

### Task P2-1: `AuthGate` routing

**Files:**
- Create: `daily_command_center/lib/screens/auth_gate.dart`
- Test: `daily_command_center/test/screens/auth_gate_test.dart`

`AuthGate` decides, on build, between `LoginScreen` (no active profile) and `AppShell` (active profile). It exposes a way to refresh after login/logout (a simple `setState` via an `InheritedWidget`/callback). Keep it minimal: a `StatefulWidget` that reads `ProfileRepository.activeId()` and rebuilds when `AuthGate.of(context).refresh()` is called.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/screens/auth_gate.dart';
import 'package:daily_command_center/screens/login_screen.dart';
import 'package:daily_command_center/screens/app_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ProfileScope.setActive(null));

  testWidgets('no active profile → LoginScreen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('active profile → AppShell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.create('Cyrus');
    await tester.pumpWidget(const MaterialApp(home: AuthGate()));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/auth_gate_test.dart`
Expected: FAIL — `AuthGate`/`LoginScreen`/`AppShell` not defined. (Stub LoginScreen/AppShell minimally in P2-2/P4 — to make this test compile, create thin placeholders first if doing strict TDD; otherwise sequence P2-2 + P4-1 before running.)

- [ ] **Step 3: Implement `auth_gate.dart`**

```dart
import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import 'login_screen.dart';
import 'app_shell.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  static _AuthGateState of(BuildContext context) =>
      context.findAncestorStateOfType<_AuthGateState>()!;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final id = await ProfileRepository.activeId();
    if (!mounted) return;
    setState(() {
      _activeId = id;
      _loading = false;
    });
  }

  /// Re-read the active profile (call after login / logout).
  void refresh() => _refresh();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _activeId == null ? const LoginScreen() : AppShell(profileId: _activeId!);
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/auth_gate_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/auth_gate.dart daily_command_center/test/screens/auth_gate_test.dart
git commit -m "feat(profiles): AuthGate routing (login vs shell)"
```

### Task P2-2: `LoginScreen` (profile picker)

**Files:**
- Create: `daily_command_center/lib/screens/login_screen.dart`
- Test: `daily_command_center/test/screens/login_screen_test.dart`

Shows existing profiles as tappable cards (avatar = first initial), plus a "New profile" name field. Tapping an existing profile → `ProfileRepository.setActive(id)` → `AuthGate.of(context).refresh()`. Entering a new name → if it exists, enter it; else push `OnboardingScreen(displayName)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => ProfileScope.setActive(null));

  testWidgets('lists existing profiles', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.create('Cyrus');
    await ProfileRepository.setActive(null);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Cyrus'), findsOneWidget);
  });

  testWidgets('tapping a profile makes it active', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.create('Cyrus');
    await ProfileRepository.setActive(null);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cyrus'));
    await tester.pumpAndSettle();
    expect(await ProfileRepository.activeId(), 'cyrus');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: FAIL — `LoginScreen` not defined.

- [ ] **Step 3: Implement `login_screen.dart`** (polished; uses `AppColors` + fonts)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/profile_repository.dart';
import '../main.dart';
import 'auth_gate.dart';
import 'onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameCtrl = TextEditingController();
  List<ProfileMeta> _profiles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ProfileRepository.listProfiles();
    if (mounted) setState(() => _profiles = p);
  }

  Future<void> _enter(String id) async {
    await ProfileRepository.setActive(id);
    if (mounted) AuthGate.of(context).refresh();
  }

  Future<void> _continueNew() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final id = ProfileRepository.idFor(name);
    if (await ProfileRepository.exists(id)) {
      await _enter(id);
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OnboardingScreen(displayName: name),
    ));
    if (mounted) AuthGate.of(context).refresh(); // onboarding set the active profile
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 64),
              Text('Reminders 2',
                  style: GoogleFonts.fraunces(fontSize: 40, fontWeight: FontWeight.w900, color: AppColors.cream, height: 1.0)),
              const SizedBox(height: 8),
              Text('Who’s running the day?',
                  style: GoogleFonts.fraunces(fontSize: 16, fontStyle: FontStyle.italic, color: AppColors.muted)),
              const SizedBox(height: 32),
              Expanded(
                child: ListView(
                  children: [
                    for (final p in _profiles) _ProfileTile(meta: p, onTap: () => _enter(p.id)),
                    const SizedBox(height: 16),
                    _NewProfileField(controller: _nameCtrl, onSubmit: _continueNew),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final ProfileMeta meta;
  final VoidCallback onTap;
  const _ProfileTile({required this.meta, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = meta.displayName.isEmpty ? '?' : meta.displayName[0].toUpperCase();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(radius: 24, backgroundColor: AppColors.terra,
                    child: Text(initial, style: const TextStyle(color: AppColors.bg, fontWeight: FontWeight.w800, fontSize: 20))),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meta.displayName, style: const TextStyle(color: AppColors.cream, fontSize: 17, fontWeight: FontWeight.w700)),
                      if (meta.archetype.isNotEmpty)
                        Text(meta.archetype, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.dim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewProfileField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  const _NewProfileField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.add, color: AppColors.moss),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.cream),
              decoration: const InputDecoration(border: InputBorder.none, hintText: 'New profile name',
                  hintStyle: TextStyle(color: AppColors.dim)),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          TextButton(onPressed: onSubmit, child: const Text('Continue', style: TextStyle(color: AppColors.terra))),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/login_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/login_screen.dart daily_command_center/test/screens/login_screen_test.dart
git commit -m "feat(profiles): LoginScreen profile picker"
```

---

## Phase 3 — Onboarding stub

### Task P3-1: Build a new profile's plan from the seed + choices

**Files:**
- Create: `daily_command_center/lib/logic/onboarding.dart`
- Test: `daily_command_center/test/logic/onboarding_test.dart`

Pure logic, separated from the UI: given the bundled seed `Plan` and the user's per-day template choices, produce the new profile's `Plan`. Times/templates come from the seed (rich, already authored); the stub only sets the week shape + meta title. This is the seam the real interview/AI replaces later.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/logic/onboarding.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildOnboardedPlan clones the seed and applies week choices + title', () async {
    final seed = await AppStore.loadSeedPlan(); // reads asset, no storage
    final choices = {
      'mon': 'office', 'tue': 'wfh', 'wed': 'office', 'thu': 'wfh',
      'fri': 'office', 'sat': 'weekend', 'sun': 'weekend_sun',
    };
    final plan = OnboardingLogic.buildPlan(seed: seed, displayName: 'Alex', weekChoices: choices, trainingDays: 3);

    expect(plan.meta.title, contains('Alex'));
    expect(plan.week['tue']!.templateId, 'wfh');
    // training count respects the request and the plan's training rules
    expect(plan.week.values.where((w) => w.training).length, 3);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/logic/onboarding_test.dart`
Expected: FAIL — `OnboardingLogic` / `AppStore.loadSeedPlan` not defined.

- [ ] **Step 3a: Add `loadSeedPlan` to `store.dart`** (reads the asset without seeding storage)

```dart
  static Future<Plan> loadSeedPlan() async {
    final seedRaw = await rootBundle.loadString(_seedAsset);
    return Plan.fromJson(jsonDecode(seedRaw) as Map<String, dynamic>);
  }
```

- [ ] **Step 3b: Implement `onboarding.dart`**

```dart
import '../data/models.dart';
import 'planner.dart';

class OnboardingLogic {
  /// Clone [seed] into a new profile's plan: apply the chosen template per day,
  /// set the meta title, then let the planner space [trainingDays] across the week.
  static Plan buildPlan({
    required Plan seed,
    required String displayName,
    required Map<String, String> weekChoices,
    required int trainingDays,
  }) {
    final week = <String, WeekEntry>{};
    seed.week.forEach((day, entry) {
      final templateId = weekChoices[day] ?? entry.templateId;
      week[day] = entry.copyWith(templateId: templateId, training: false);
    });

    var plan = seed.copyWith(week: week).withTitle('${displayName.trim()}’s plan');
    // Reuse the generalized planner to place training days (respects avoidConsecutive).
    return PlannerLogic.applyTrainingFrequency(plan, trainingDays);
  }
}
```

> `Plan.withTitle` and `PlannerLogic.applyTrainingFrequency` are small additions. If the v3 planner already exposes an equivalent (e.g. `setFrequency`), use that and delete the shim. Add `withTitle` to `Plan`:
>
> ```dart
>   Plan withTitle(String title) => Plan(
>         schemaVersion: schemaVersion, meta: PlanMeta(
>           title: title, timezone: meta.timezone, lifestyleArchetype: meta.lifestyleArchetype,
>           generatedAt: meta.generatedAt, improvementAreas: meta.improvementAreas, equipment: meta.equipment),
>         dayTemplates: dayTemplates, week: week, weekEditor: weekEditor, training: training,
>         workouts: workouts, nutrition: nutrition, goals: goals);
> ```
>
> And `applyTrainingFrequency(Plan, int)` to `planner.dart`: set N days using the existing spacing search, return `plan.copyWith(week: …)`. (The v3 planner generalization task already builds the spacing search over `frequencyPerWeek`; this wraps it to set an arbitrary N and write back to `plan.week`.)

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/logic/onboarding_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/logic/onboarding.dart daily_command_center/lib/data/store.dart daily_command_center/lib/data/models.dart daily_command_center/lib/logic/planner.dart daily_command_center/test/logic/onboarding_test.dart
git commit -m "feat(onboarding): build a new profile's plan from the seed + choices"
```

### Task P3-2: `OnboardingScreen` (stub UI)

**Files:**
- Create: `daily_command_center/lib/screens/onboarding_screen.dart`
- Test: `daily_command_center/test/screens/onboarding_screen_test.dart`

Three steps with a progress indicator: welcome → per-day template chips → training-days slider → "Create". On finish: `ProfileRepository.create(displayName)` (sets active scope), build the plan via `OnboardingLogic`, `AppStore.savePlan(plan)`, pop back to login which refreshes into the shell. Times shown read-only with a "customize later" note.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';
import 'package:daily_command_center/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => ProfileScope.setActive(null));

  testWidgets('completing onboarding creates the profile with a saved plan', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen(displayName: 'Alex')));
    await tester.pumpAndSettle();

    // Advance through the stub to the end (Next ×N then Create).
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(await ProfileRepository.exists('alex'), true);
    ProfileScope.setActive('alex');
    final plan = await AppStore.loadPlan();
    expect(plan.meta.title, contains('Alex'));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/onboarding_screen_test.dart`
Expected: FAIL — `OnboardingScreen` not defined.

- [ ] **Step 3: Implement `onboarding_screen.dart`** (polished `PageView` with a progress dot row)

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/store.dart';
import '../data/profile_repository.dart';
import '../logic/onboarding.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  final String displayName;
  const OnboardingScreen({super.key, required this.displayName});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _page = PageController();
  int _index = 0;
  int _trainingDays = 4;
  final Map<String, String> _week = {
    'mon': 'office', 'tue': 'office', 'wed': 'wfh', 'thu': 'office',
    'fri': 'office', 'sat': 'weekend', 'sun': 'weekend_sun',
  };

  static const _steps = 3;

  Future<void> _finish() async {
    final seed = await AppStore.loadSeedPlan();
    await ProfileRepository.create(widget.displayName); // sets active scope
    final plan = OnboardingLogic.buildPlan(
      seed: seed, displayName: widget.displayName, weekChoices: _week, trainingDays: _trainingDays);
    await AppStore.savePlan(plan);
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_index < _steps - 1) {
      _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _ProgressDots(count: _steps, index: _index),
            Expanded(
              child: PageView(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  _Welcome(name: widget.displayName),
                  _WeekStep(week: _week, onChange: (d, t) => setState(() => _week[d] = t)),
                  _TrainingStep(days: _trainingDays, onChange: (n) => setState(() => _trainingDays = n)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.terra, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: _next,
                  child: Text(_index == _steps - 1 ? 'Create' : 'Next',
                      style: const TextStyle(color: AppColors.bg, fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int count, index;
  const _ProgressDots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: i == index ? 22 : 8, height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == index ? AppColors.terra : AppColors.line,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      );
}

class _Welcome extends StatelessWidget {
  final String name;
  const _Welcome({required this.name});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, $name.',
                style: GoogleFonts.fraunces(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.cream)),
            const SizedBox(height: 12),
            const Text(
              'We’ll set up a starting routine you can run from day one. '
              'You can fine-tune everything later — the times come from a sensible default for now.',
              style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      );
}

class _WeekStep extends StatelessWidget {
  final Map<String, String> week;
  final void Function(String day, String template) onChange;
  const _WeekStep({required this.week, required this.onChange});

  static const _labels = {'office': 'Office', 'wfh': 'WFH', 'weekend': 'Weekend', 'weekend_sun': 'Weekend'};

  @override
  Widget build(BuildContext context) {
    const days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Your week', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.cream)),
        const SizedBox(height: 4),
        const Text('Pick the shape of each day.', style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        for (final d in days)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(width: 44, child: Text(d.toUpperCase(), style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w700))),
                const SizedBox(width: 8),
                for (final t in const ['office', 'wfh'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(_labels[t]!),
                      selected: week[d] == t,
                      onSelected: (_) => onChange(d, t),
                    ),
                  ),
                if (d == 'sat' || d == 'sun')
                  const Chip(label: Text('Weekend')),
              ],
            ),
          ),
      ],
    );
  }
}

class _TrainingStep extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChange;
  const _TrainingStep({required this.days, required this.onChange});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Training days', style: GoogleFonts.fraunces(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.cream)),
            const SizedBox(height: 4),
            const Text('How many days a week do you want to train? We’ll space them out for you.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 24),
            Text('$days days', style: GoogleFonts.fraunces(fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.terra)),
            Slider(
              value: days.toDouble(), min: 1, max: 6, divisions: 5, activeColor: AppColors.terra,
              onChanged: (v) => onChange(v.round()),
            ),
          ],
        ),
      );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/onboarding_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/onboarding_screen.dart daily_command_center/test/screens/onboarding_screen_test.dart
git commit -m "feat(onboarding): stub onboarding screen → creates profile + plan"
```

---

## Phase 4 — App shell + side panel

### Task P4-1: Extract `TodayView` from `HomeScreen`

**Files:**
- Create: `daily_command_center/lib/widgets/today_view.dart`
- Modify: `daily_command_center/lib/screens/home_screen.dart`
- Test: `daily_command_center/test/widgets/today_view_test.dart`

`AppShell` needs the dashboard as a body widget (no Scaffold). Move `HomeScreen`'s build body (header + NowCard + WeekPlanner + state/loading/toggle logic) into `TodayView`. `HomeScreen` becomes a thin `Scaffold(body: TodayView())` so its existing test still passes.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/widgets/today_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ProfileScope.setActive('cyrus');
  });
  tearDown(() => ProfileScope.setActive(null));

  testWidgets('TodayView renders the dashboard without a Scaffold of its own', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TodayView())));
    await tester.pumpAndSettle();
    expect(find.byType(TodayView), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/today_view_test.dart`
Expected: FAIL — `TodayView` not defined.

- [ ] **Step 3: Create `today_view.dart`** by moving the body of `_HomeScreenState` into a `TodayView` `StatefulWidget` (same `_load`, `_tally`, `_toggleDone`, `_updatePlan`, `_buildHeader`, and the `CustomScrollView`). The header reads the active profile's display name instead of the hardcoded "CYRUS · DAILY COMMAND CENTER":

```dart
// In the header builder, replace the hardcoded label:
//   const Text('CYRUS · DAILY COMMAND CENTER', ...)
// with the active profile's name (loaded once in initState):
Text('${_displayName.toUpperCase()} · DAILY COMMAND CENTER',
    style: const TextStyle(fontSize: 10, letterSpacing: 3, color: AppColors.terra, fontWeight: FontWeight.w600)),
```

Load `_displayName` in `initState` via `ProfileRepository.listProfiles()` filtered by `ProfileScope.activeId`. Then reduce `home_screen.dart` to:

```dart
import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/today_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(backgroundColor: AppColors.bg, body: TodayView());
}
```

- [ ] **Step 4: Run to verify it passes** — and the existing `now_card`/home tests stay green.

Run: `flutter test test/widgets/today_view_test.dart` → PASS
Run: `flutter test` → green.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/today_view.dart daily_command_center/lib/screens/home_screen.dart daily_command_center/test/widgets/today_view_test.dart
git commit -m "refactor(shell): extract TodayView from HomeScreen"
```

### Task P4-2: `ComingSoon` placeholder

**Files:**
- Create: `daily_command_center/lib/widgets/coming_soon.dart`
- Test: `daily_command_center/test/widgets/coming_soon_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:daily_command_center/widgets/coming_soon.dart';

void main() {
  testWidgets('shows the title and a coming-soon message', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ComingSoon(title: 'Workouts', icon: Icons.fitness_center))));
    expect(find.text('Workouts'), findsOneWidget);
    expect(find.textContaining('Coming soon'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/widgets/coming_soon_test.dart`
Expected: FAIL — `ComingSoon` not defined.

- [ ] **Step 3: Implement `coming_soon.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';

class ComingSoon extends StatelessWidget {
  final String title;
  final IconData icon;
  const ComingSoon({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.dim),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.fraunces(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.cream)),
            const SizedBox(height: 8),
            const Text('Coming soon.', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/widgets/coming_soon_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/widgets/coming_soon.dart daily_command_center/test/widgets/coming_soon_test.dart
git commit -m "feat(shell): reusable ComingSoon placeholder"
```

### Task P4-3: `AppShell` + drawer

**Files:**
- Create: `daily_command_center/lib/screens/app_shell.dart`
- Test: `daily_command_center/test/screens/app_shell_test.dart`

`AppShell` is a `Scaffold` with an `AppBar` (hamburger + active profile name), a `Drawer` (the approved structure), and a body that swaps by a `NavSection` enum. Today/Full Timeline/Week Planner are live; Workouts/Goals/Nutrition/Weekly Review use `ComingSoon`; Settings + Logout at the bottom.

> Live bodies bind to post-v3 widgets: **Today** = `TodayView`; **Full Timeline** = the post-v3 `TodayScreen` (it takes a `Plan` — load it in the shell or wrap it); **Week Planner** = the post-v3 `WeekPlanner`. If a v3 **Weekly Review** surface exists, wire it here instead of a placeholder.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/screens/app_shell.dart';
import 'package:daily_command_center/widgets/coming_soon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.create('Cyrus');
  });
  tearDown(() => ProfileScope.setActive(null));

  testWidgets('opens the drawer and navigates to a placeholder section', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AppShell(profileId: 'cyrus')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('Workouts & Log'), findsOneWidget);

    await tester.tap(find.text('Workouts & Log'));
    await tester.pumpAndSettle();
    expect(find.byType(ComingSoon), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/app_shell_test.dart`
Expected: FAIL — `AppShell` not defined.

- [ ] **Step 3: Implement `app_shell.dart`**

```dart
import 'package:flutter/material.dart';
import '../data/profile_repository.dart';
import '../main.dart';
import '../widgets/today_view.dart';
import '../widgets/coming_soon.dart';
import 'settings_screen.dart';

enum NavSection { today, timeline, week, workouts, goals, nutrition, review, settings }

class AppShell extends StatefulWidget {
  final String profileId;
  const AppShell({super.key, required this.profileId});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  NavSection _section = NavSection.today;
  ProfileMeta? _meta;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final list = await ProfileRepository.listProfiles();
    if (mounted) {
      setState(() => _meta = list.firstWhere((m) => m.id == widget.profileId,
          orElse: () => ProfileMeta(id: widget.profileId, displayName: widget.profileId)));
    }
  }

  String get _title => switch (_section) {
        NavSection.today => 'Today',
        NavSection.timeline => 'Full Timeline',
        NavSection.week => 'Week Planner',
        NavSection.workouts => 'Workouts & Log',
        NavSection.goals => 'Goals',
        NavSection.nutrition => 'Nutrition',
        NavSection.review => 'Weekly Review',
        NavSection.settings => 'Settings',
      };

  Widget get _body => switch (_section) {
        NavSection.today => const TodayView(),
        // Post-v3 live screens — wrap as needed (they take a Plan):
        NavSection.timeline => const _PlanScreen(builder: _timelineBuilder),
        NavSection.week => const _PlanScreen(builder: _weekBuilder),
        NavSection.workouts => const ComingSoon(title: 'Workouts & Log', icon: Icons.fitness_center),
        NavSection.goals => const ComingSoon(title: 'Goals', icon: Icons.flag),
        NavSection.nutrition => const ComingSoon(title: 'Nutrition', icon: Icons.restaurant),
        NavSection.review => const ComingSoon(title: 'Weekly Review', icon: Icons.insights),
        NavSection.settings => const SettingsScreen(),
      };

  void _go(NavSection s) {
    setState(() => _section = s);
    Navigator.of(context).pop(); // close drawer
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(_title),
      ),
      drawer: _AppDrawer(meta: _meta, current: _section, onSelect: _go),
      body: _body,
    );
  }
}

class _AppDrawer extends StatelessWidget {
  final ProfileMeta? meta;
  final NavSection current;
  final void Function(NavSection) onSelect;
  const _AppDrawer({required this.meta, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final name = meta?.displayName ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return Drawer(
      backgroundColor: AppColors.panel,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.bg2),
            child: Row(children: [
              CircleAvatar(radius: 26, backgroundColor: AppColors.terra,
                  child: Text(initial, style: const TextStyle(color: AppColors.bg, fontWeight: FontWeight.w800, fontSize: 22))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(name, style: const TextStyle(color: AppColors.cream, fontSize: 18, fontWeight: FontWeight.w700)),
                if ((meta?.archetype ?? '').isNotEmpty)
                  Text(meta!.archetype, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
            ]),
          ),
          _label('PLAN'),
          _item(Icons.home, 'Today', NavSection.today, current, onSelect),
          _item(Icons.view_agenda, 'Full Timeline', NavSection.timeline, current, onSelect),
          _item(Icons.calendar_month, 'Week Planner', NavSection.week, current, onSelect),
          _label('TRACK'),
          _item(Icons.fitness_center, 'Workouts & Log', NavSection.workouts, current, onSelect),
          _item(Icons.flag, 'Goals', NavSection.goals, current, onSelect),
          _item(Icons.restaurant, 'Nutrition', NavSection.nutrition, current, onSelect),
          _label('REVIEW'),
          _item(Icons.insights, 'Weekly Review', NavSection.review, current, onSelect),
          const Divider(color: AppColors.line),
          _item(Icons.settings, 'Settings', NavSection.settings, current, onSelect),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(s, style: const TextStyle(color: AppColors.dim, fontSize: 10, letterSpacing: 2)),
      );

  Widget _item(IconData icon, String label, NavSection s, NavSection current, void Function(NavSection) onSelect) {
    final active = s == current;
    return Container(
      color: active ? AppColors.panel2 : null,
      child: ListTile(
        leading: Icon(icon, color: active ? AppColors.terra : AppColors.muted),
        title: Text(label, style: TextStyle(color: active ? AppColors.cream : AppColors.muted, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        onTap: () => onSelect(s),
        shape: active ? const Border(left: BorderSide(color: AppColors.terra, width: 3)) : null,
      ),
    );
  }
}

// Loads the active Plan once, then hands it to a builder (for post-v3 screens
// that require a Plan argument). Replace `_timelineBuilder`/`_weekBuilder` with
// the real post-v3 widget constructors.
typedef _PlanWidgetBuilder = Widget Function(dynamic plan);
class _PlanScreen extends StatelessWidget {
  final _PlanWidgetBuilder builder;
  const _PlanScreen({required this.builder});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Wire post-v3 Plan screen here', style: TextStyle(color: AppColors.muted)));
}
Widget _timelineBuilder(dynamic plan) => const SizedBox.shrink();
Widget _weekBuilder(dynamic plan) => const SizedBox.shrink();
```

> **Integration note:** `_PlanScreen`/`_timelineBuilder`/`_weekBuilder` are stubs because the post-v3 `TodayScreen`/`WeekPlanner` constructors aren't pinned until v3 ships. When executing, replace them with the real screens: load the `Plan` via `AppStore.loadPlan()` (a `FutureBuilder`) and pass it in. The test above only exercises the drawer + a placeholder section, so it passes against the stubs; add a live-section test once the real constructors exist.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/app_shell_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/app_shell.dart daily_command_center/test/screens/app_shell_test.dart
git commit -m "feat(shell): AppShell + navigation drawer"
```

---

## Phase 5 — Settings + logout

### Task P5-1: Settings actions (logic)

**Files:**
- Modify: `daily_command_center/lib/data/profile_repository.dart`
- Test: `daily_command_center/test/data/profile_actions_test.dart`

Add `resetPlan` (re-seed the active profile's plan from the asset) and `clearHistory` (wipe this profile's logs + adherence + daily state, keep the plan).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.create('Cyrus');
  });
  tearDown(() => ProfileScope.setActive(null));

  test('clearHistory wipes logs but keeps the plan', () async {
    await AppStore.savePlan(await AppStore.loadPlan());
    await AppStore.saveLogs('A', [const WorkoutLog(date: '2026-06-08', reps: '9')]);
    await ProfileRepository.clearHistory('cyrus');
    expect(await AppStore.loadLogs('A'), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('p_cyrus__activePlan'), isNotNull); // plan survives
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/data/profile_actions_test.dart`
Expected: FAIL — `clearHistory` not defined.

- [ ] **Step 3: Add the actions** (inside `ProfileRepository`)

```dart
  /// Wipe a profile's logs, adherence, and daily state — keep the plan.
  static Future<void> clearHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = ProfileScope.prefixFor(id);
    bool isHistory(String base) =>
        base.startsWith('log_') || base.startsWith('done_') ||
        base.startsWith('adherence_') || base.startsWith('state_');
    for (final k in prefs.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      if (isHistory(k.substring(prefix.length))) await prefs.remove(k);
    }
  }

  /// Re-seed the active profile's plan from the bundled asset.
  static Future<void> resetPlan() async => AppStore.savePlan(await AppStore.loadSeedPlan());
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/data/profile_actions_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/data/profile_repository.dart daily_command_center/test/data/profile_actions_test.dart
git commit -m "feat(settings): clearHistory + resetPlan actions"
```

### Task P5-2: `SettingsScreen` + logout

**Files:**
- Create: `daily_command_center/lib/screens/settings_screen.dart`
- Test: `daily_command_center/test/screens/settings_screen_test.dart`

Sections: Profile (display name, archetype), Log out / switch profile, Delete profile, Export / Import (a dialog with a copyable/pastable text field), Reset plan, Clear history, About (version + health disclaimer). Logout/delete call `ProfileRepository.setActive(null)`/`delete` then bubble to `AuthGate.of(context).refresh()`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:daily_command_center/data/profile_scope.dart';
import 'package:daily_command_center/data/profile_repository.dart';
import 'package:daily_command_center/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ProfileRepository.create('Cyrus');
  });
  tearDown(() => ProfileScope.setActive(null));

  testWidgets('shows the core settings rows', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete this profile'), findsOneWidget);
    expect(find.text('Export data'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL — `SettingsScreen` not defined.

- [ ] **Step 3: Implement `settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/profile_repository.dart';
import '../data/profile_scope.dart';
import '../main.dart';
import 'auth_gate.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await ProfileRepository.setActive(null);
    if (context.mounted) AuthGate.of(context).refresh();
  }

  Future<void> _delete(BuildContext context) async {
    final id = ProfileScope.activeId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Delete this profile?', style: TextStyle(color: AppColors.cream)),
        content: const Text('This erases this profile’s plan and history on this device. Export first if you want a backup.',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: AppColors.terra))),
        ],
      ),
    );
    if (ok == true) {
      await ProfileRepository.delete(id);
      if (context.mounted) AuthGate.of(context).refresh();
    }
  }

  Future<void> _export(BuildContext context) async {
    final id = ProfileScope.activeId;
    if (id == null) return;
    final blob = await ProfileRepository.exportProfile(id);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text('Export data', style: TextStyle(color: AppColors.cream)),
        content: SelectableText(blob, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        actions: [
          TextButton(
            onPressed: () { Clipboard.setData(ClipboardData(text: blob)); Navigator.pop(c); },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _Section('PROFILE'),
        ListTile(
          leading: const Icon(Icons.logout, color: AppColors.muted),
          title: const Text('Log out', style: TextStyle(color: AppColors.cream)),
          subtitle: const Text('Switch profile', style: TextStyle(color: AppColors.muted)),
          onTap: () => _logout(context),
        ),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: AppColors.terra),
          title: const Text('Delete this profile', style: TextStyle(color: AppColors.cream)),
          onTap: () => _delete(context),
        ),
        const _Section('DATA'),
        ListTile(
          leading: const Icon(Icons.upload_file, color: AppColors.muted),
          title: const Text('Export data', style: TextStyle(color: AppColors.cream)),
          onTap: () => _export(context),
        ),
        ListTile(
          leading: const Icon(Icons.restart_alt, color: AppColors.muted),
          title: const Text('Reset plan to default', style: TextStyle(color: AppColors.cream)),
          onTap: () => ProfileRepository.resetPlan(),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services, color: AppColors.muted),
          title: const Text('Clear logged history', style: TextStyle(color: AppColors.cream)),
          onTap: () { final id = ProfileScope.activeId; if (id != null) ProfileRepository.clearHistory(id); },
        ),
        const _Section('ABOUT'),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Reminders 2 · personal daily dashboard.\n\nThis is general fitness information, not medical advice.',
              style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.5)),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String label;
  const _Section(this.label);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
        child: Text(label, style: const TextStyle(color: AppColors.dim, fontSize: 10, letterSpacing: 2)),
      );
}
```

> Import is the inverse of export (a paste dialog → `ProfileRepository.importProfile`); add it next to Export when wiring the UI. Left out of the required test to keep it focused.

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add daily_command_center/lib/screens/settings_screen.dart daily_command_center/test/screens/settings_screen_test.dart
git commit -m "feat(settings): SettingsScreen + logout/delete/export"
```

---

## Phase 6 — Visual polish pass

### Task P6-1: Polish login, onboarding, drawer, transitions

**Files:**
- Modify: `login_screen.dart`, `onboarding_screen.dart`, `app_shell.dart`, `settings_screen.dart`

Not strictly TDD (visual). **Invoke the `frontend-design` skill** and apply it across the new surfaces. Checklist (spec §7):

- [ ] Consistent spacing scale + card styling across login/onboarding/drawer/settings.
- [ ] Login: warm, branded, calm; profile avatars + clear primary action; empty state ("no profiles yet — create one") reads intentionally.
- [ ] Onboarding: friendly copy, visible progress, low-friction taps/sliders, encouraging finish screen.
- [ ] Drawer: smooth open/close, terracotta active left-rail, grouped labels, profile header, logout visually distinct.
- [ ] Tasteful section transitions in `AppShell` (e.g. `AnimatedSwitcher` on the body).
- [ ] Loading/empty states aren't bare spinners where it matters.
- [ ] Accessible contrast + ≥48px tap targets.

- [ ] **Run the full suite** to confirm no regressions: `flutter test` → all green.
- [ ] **Manual check** on device per `CONTINUE.md` "How to run": login → switch profiles → onboarding a new name → drawer nav → settings → logout.
- [ ] **Commit**

```bash
git add -A
git commit -m "style(profiles): visual polish pass on login/onboarding/shell/settings"
```

---

## Self-review (against the spec)

**Spec coverage:**
- §1 login = local profile picker → P2-2 ✓ · cyrus seeded → P1-3 ✓ · new user onboarding → P3 ✓ · logout → P5-2 ✓ · side panel → P4-3 ✓ · scalable (add profile/section without core rework) → ProfileScope/Repository + NavSection ✓
- §2 routing/AuthGate/cyrus first-run → P0-2, P1-3, P2-1 ✓
- §3 storage (revised to prefix; file→export) → P0-1/P0-3, P1-4 ✓
- §4 onboarding stub produces a valid plan → P3-1/P3-2 ✓
- §5 app shell, drawer, screen split, profile name in header → P4-1/P4-3 ✓
- §6 settings scope (profile, delete, export/import, reset, clear, about) → P5-1/P5-2 ✓ (import UI noted as a follow-on in P5-2)
- §7 visual polish → P6-1 ✓ (and tasteful build-as-you-go)
- §8 testing (repository isolation, routing, login, onboarding, settings, regression green) → covered per task ✓

**Placeholder scan:** The only intentional stubs are the post-v3 live-screen constructors in `AppShell` (`_PlanScreen`/`_timelineBuilder`/`_weekBuilder`), flagged explicitly because those widget signatures don't exist until v3 ships — the executor wires the real `TodayScreen`/`WeekPlanner`/Weekly-Review there. Everything else is concrete.

**Type consistency:** `ProfileScope.key/prefixFor/isProfileKey/setActive/activeId`, `ProfileRepository.{idFor,listProfiles,exists,activeId,restoreActive,setActive,create,delete,ensureFirstRun,exportProfile,importProfile,clearHistory,resetPlan}`, `ProfileMeta{id,displayName,archetype}`, `NavSection`, `AppStore.{loadPlan,savePlan,loadSeedPlan,loadLogs,saveLogs}`, `OnboardingLogic.buildPlan`, `Plan.{copyWith,withTitle}`, `PlannerLogic.applyTrainingFrequency` — names are used consistently across tasks.

**Dependency:** Requires v3 storage layer (Phases A–B) merged. If profiles must precede v3, the same `ProfileScope` wraps today's `weekPlan`/`log_*`/`done_*`/`adherence_*` keys instead — only the `Plan`/seed-specific tasks (P3, `loadSeedPlan`, `resetPlan`) change, and onboarding would build a `WeekPlan` rather than a v3 `Plan`.
