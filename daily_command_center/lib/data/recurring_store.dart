import 'models.dart';
import 'store.dart';

/// Thin façade over [ProfileRepository] for recurring custom task operations.
/// All reads/writes go through [AppStore.repo] so tests can inject a temp dir.
class RecurringStore {
  static Future<List<RecurringCustomTask>> loadAll() async {
    final doc = await AppStore.repo.loadActive();
    return doc.recurringTasks;
  }

  /// Upsert a recurring task — replaces any existing task with the same id.
  static Future<void> save(RecurringCustomTask task) async {
    final doc = await AppStore.repo.loadActive();
    final updated = [
      ...doc.recurringTasks.where((t) => t.id != task.id),
      task,
    ];
    await AppStore.repo.save(doc.copyWith(recurringTasks: updated));
  }

  static Future<void> removeById(String id) async {
    final doc = await AppStore.repo.loadActive();
    final updated = doc.recurringTasks.where((t) => t.id != id).toList();
    await AppStore.repo.save(doc.copyWith(recurringTasks: updated));
  }

  /// All recurring tasks active on [dateIso] ('yyyy-MM-dd').
  static Future<List<RecurringCustomTask>> activeFor(String dateIso) async {
    final all = await loadAll();
    return all.where((t) => t.activeDates.contains(dateIso)).toList();
  }
}
