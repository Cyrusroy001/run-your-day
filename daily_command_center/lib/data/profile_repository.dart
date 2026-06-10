import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// The logged-in profile id, or null when logged out. [AuthGate] listens to
/// this; [ProfileRepository] keeps it in sync with the persisted pointer.
///
/// NOTE: boots as null. main.dart must initialize it from the persisted
/// pointer (`activeProfileIdOrNull`) before runApp (done in the AuthGate task).
final ValueNotifier<String?> activeProfile = ValueNotifier<String?>(null);

/// The complete on-disk state for one profile — the v3 file-per-profile unit.
/// Holds the immutable Plan blueprint plus every per-profile data stream
/// (daily state, workout logs, done-sets, adherence). Because a profile *is*
/// a single JSON document, export/import is just copying this file.
class ProfileDoc {
  final String id;
  final String displayName;
  final Plan plan;
  final Map<String, DailyState> states;        // 'yyyy-MM-dd' -> state
  final Map<String, List<WorkoutLog>> logs;     // workoutKey -> logs
  final Map<String, List<String>> done;         // 'yyyy-MM-dd' -> block signatures
  final Map<String, Map<String, int>> adherence; // 'yyyy-MM-dd' -> {done,total}
  final List<RecurringCustomTask> recurringTasks;
  final List<String> skippedRepeatIds; // custom task IDs the user declined to repeat

  const ProfileDoc({
    required this.id,
    required this.displayName,
    required this.plan,
    this.states = const {},
    this.logs = const {},
    this.done = const {},
    this.adherence = const {},
    this.recurringTasks = const [],
    this.skippedRepeatIds = const [],
  });

  factory ProfileDoc.fromJson(Map<String, dynamic> j) => ProfileDoc(
        id: j['id'] as String,
        displayName: (j['displayName'] ?? j['id']) as String,
        plan: Plan.fromJson(j['plan'] as Map<String, dynamic>),
        states: ((j['states'] ?? const {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, DailyState.fromJson(v as Map<String, dynamic>))),
        logs: ((j['logs'] ?? const {}) as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, (v as List).map((e) => WorkoutLog.fromJson(e as Map<String, dynamic>)).toList())),
        done: ((j['done'] ?? const {}) as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as List).map((e) => e as String).toList())),
        adherence: ((j['adherence'] ?? const {}) as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, (v as Map<String, dynamic>).map((kk, vv) => MapEntry(kk, (vv as num).toInt())))),
        recurringTasks: ((j['recurringTasks'] ?? const []) as List)
            .map((e) => RecurringCustomTask.fromJson(e as Map<String, dynamic>))
            .toList(),
        skippedRepeatIds: ((j['skippedRepeatIds'] ?? const []) as List)
            .map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'plan': plan.toJson(),
        'states': states.map((k, v) => MapEntry(k, v.toJson())),
        'logs': logs.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
        'done': done,
        'adherence': adherence,
        'recurringTasks': recurringTasks.map((t) => t.toJson()).toList(),
        'skippedRepeatIds': skippedRepeatIds,
      };

  ProfileDoc copyWith({
    String? displayName,
    Plan? plan,
    Map<String, DailyState>? states,
    Map<String, List<WorkoutLog>>? logs,
    Map<String, List<String>>? done,
    Map<String, Map<String, int>>? adherence,
    List<RecurringCustomTask>? recurringTasks,
    List<String>? skippedRepeatIds,
  }) =>
      ProfileDoc(
        id: id,
        displayName: displayName ?? this.displayName,
        plan: plan ?? this.plan,
        states: states ?? this.states,
        logs: logs ?? this.logs,
        done: done ?? this.done,
        adherence: adherence ?? this.adherence,
        recurringTasks: recurringTasks ?? this.recurringTasks,
        skippedRepeatIds: skippedRepeatIds ?? this.skippedRepeatIds,
      );
}

/// Lightweight profile descriptor for the login picker / drawer header.
class ProfileMeta {
  final String id;
  final String displayName;
  final String archetype;
  const ProfileMeta({
    required this.id,
    required this.displayName,
    this.archetype = '',
  });
}

/// Owns one JSON file per profile under `<appDocuments>/profiles/<id>.json`.
/// The active-profile id is a tiny global pointer kept in SharedPreferences
/// (not profile data); everything else lives in the per-profile file.
///
/// [baseDir] is injectable so tests can use a temp directory without touching
/// the real documents directory or platform channels.
class ProfileRepository {
  ProfileRepository({Directory? baseDir, this.seedAsset = 'assets/seed_plan.json'})
      : _injectedBase = baseDir;

  final Directory? _injectedBase;
  final String seedAsset;

  static const _activeKey = 'activeProfileId';
  static const defaultProfileId = 'cyrus';

  Directory? _resolved;
  Future<Directory> _baseDir() async {
    if (_injectedBase != null) return _injectedBase;
    _resolved ??= Directory('${(await getApplicationDocumentsDirectory()).path}/profiles');
    return _resolved!;
  }

  Future<File> _file(String id) async {
    final dir = await _baseDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$id.json');
  }

  Future<String> activeProfileId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey) ?? defaultProfileId;
  }

  /// The raw active pointer — null when logged out (unlike [activeProfileId],
  /// which defaults to [defaultProfileId] for store back-compat).
  Future<String?> activeProfileIdOrNull() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  /// Log out: clear the pointer + notifier.
  Future<void> clearActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
    activeProfile.value = null;
  }

  Future<void> setActiveProfileId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
    activeProfile.value = id;
  }

  Future<List<String>> listProfiles() async {
    final dir = await _baseDir();
    if (!await dir.exists()) return const [];
    return dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
        .toList();
  }

  /// Load the active profile, seeding a fresh one from the bundled blueprint
  /// if its file does not exist yet.
  Future<ProfileDoc> loadActive() async => load(await activeProfileId());

  Future<ProfileDoc> load(String id) async {
    final file = await _file(id);
    if (await file.exists()) {
      try {
        return ProfileDoc.fromJson(jsonDecode(await file.readAsString()) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt file — fall through and re-seed.
      }
    }
    final seedRaw = await rootBundle.loadString(seedAsset);
    final plan = Plan.fromJson(jsonDecode(seedRaw) as Map<String, dynamic>);
    final doc = ProfileDoc(id: id, displayName: _titleCase(id), plan: plan);
    await save(doc);
    return doc;
  }

  Future<void> save(ProfileDoc doc) async {
    final file = await _file(doc.id);
    await file.writeAsString(jsonEncode(doc.toJson()));
  }

  static final _whitespace = RegExp(r'\s+');

  /// Lower-cased, trimmed, spaces→underscores. The storage id for a display name.
  static String idFor(String displayName) =>
      displayName.trim().toLowerCase().replaceAll(_whitespace, '_');

  /// Every profile on disk, with display name + archetype. Fully deserializes
  /// each profile file — acceptable while profile counts stay small.
  Future<List<ProfileMeta>> listProfileMetas() async {
    final ids = await listProfiles();
    final metas = <ProfileMeta>[];
    for (final id in ids) {
      final doc = await load(id);
      metas.add(ProfileMeta(
        id: doc.id,
        displayName: doc.displayName,
        archetype: doc.plan.meta.lifestyleArchetype,
      ));
    }
    return metas;
  }

  /// Create a new profile, make it active, and persist it. If [plan] is provided
  /// (onboarding), it becomes the profile's plan. If [plan] is null the profile
  /// is seeded from the bundled blueprint via [load]. Note: if a file already
  /// exists for this id, its existing data is preserved and only the display
  /// name is updated — callers create brand-new ids, so this path seeds fresh.
  Future<ProfileDoc> createProfile(String displayName, {Plan? plan}) async {
    final id = idFor(displayName);
    final ProfileDoc doc;
    if (plan != null) {
      doc = ProfileDoc(id: id, displayName: displayName.trim(), plan: plan);
      await save(doc);
    } else {
      // load() seeds + saves a fresh doc from the asset when the file is absent.
      final seeded = await load(id);
      doc = seeded.copyWith(displayName: displayName.trim());
      await save(doc);
    }
    await setActiveProfileId(id);
    return doc;
  }

  /// Delete a profile's file. If it was the active profile, log out.
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
    if (await activeProfileIdOrNull() == id) await clearActive();
  }

  /// Export a profile as a JSON string. The blob is the full [ProfileDoc]
  /// serialised by [ProfileDoc.toJson] — import it back with [importProfile].
  Future<String> exportProfile(String id) async =>
      jsonEncode((await load(id)).toJson());

  /// Recreate a profile from an exported blob. Overwrites any existing file
  /// with the same id. Returns the profile's [ProfileMeta].
  /// Does NOT change the active-profile pointer.
  Future<ProfileMeta> importProfile(String blob) async {
    final doc = ProfileDoc.fromJson(jsonDecode(blob) as Map<String, dynamic>);
    await save(doc);
    return ProfileMeta(
      id: doc.id,
      displayName: doc.displayName,
      archetype: doc.plan.meta.lifestyleArchetype,
    );
  }

  /// Wipe a profile's logged history (logs, done sets, adherence, daily states),
  /// keeping the plan and recurring tasks.
  Future<void> clearHistory(String id) async {
    final doc = await load(id);
    await save(doc.copyWith(states: {}, logs: {}, done: {}, adherence: {}));
  }

  /// Re-seed a profile's plan from the bundled blueprint, keeping history.
  Future<void> resetPlan(String id) async {
    final seedRaw = await rootBundle.loadString(seedAsset);
    final plan = Plan.fromJson(jsonDecode(seedRaw) as Map<String, dynamic>);
    final doc = await load(id);
    await save(doc.copyWith(plan: plan));
  }

  /// First-run: ensure the default `cyrus` profile exists on disk WITHOUT
  /// logging in (so the login picker shows it). Idempotent.
  Future<void> ensureSeeded() async {
    if ((await listProfiles()).isNotEmpty) return;
    await load(defaultProfileId); // load() seeds + saves cyrus.json when absent
  }

  static String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
