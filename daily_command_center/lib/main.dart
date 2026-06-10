import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'data/notifications.dart';
import 'data/profile_repository.dart';
import 'data/store.dart';
import 'data/ui_prefs.dart';
import 'theme/app_palette.dart';
import 'screens/auth_gate.dart';

// Unique name for the periodic home-widget refresh task.
const _widgetRefreshTask = 'now-widget-refresh';

// Entry point for the WorkManager background isolate. Must be a top-level
// function and kept by the compiler for the background engine, hence the pragma.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await AppStore.refreshWidgetData();
    return true;
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await Workmanager().initialize(callbackDispatcher);
  // Android's WorkManager floor is 15 min — this is the real driver of the
  // widget's "live" refresh (the appwidget updatePeriodMillis is capped at 30).
  await Workmanager().registerPeriodicTask(
    _widgetRefreshTask,
    _widgetRefreshTask,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
  final prefs = await UiPrefs.load();
  await AppStore.repo.ensureSeeded();
  activeProfile.value = await AppStore.repo.activeProfileIdOrNull();
  runApp(RemindersApp(prefs: prefs));
}

class RemindersApp extends StatefulWidget {
  final UiPrefs prefs;
  const RemindersApp({super.key, this.prefs = const UiPrefs()});

  static _RemindersAppState? of(BuildContext c) =>
      c.findAncestorStateOfType<_RemindersAppState>();

  @override
  State<RemindersApp> createState() => _RemindersAppState();
}

class _RemindersAppState extends State<RemindersApp> {
  late UiPrefs _prefs = widget.prefs;

  UiPrefs get prefs => _prefs;

  void updatePrefs(UiPrefs p) {
    setState(() => _prefs = p);
    UiPrefs.save(p);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminders 2',
      theme: AppPalette.lightTheme,
      darkTheme: AppPalette.darkTheme,
      themeMode: _prefs.themeMode,
      builder: (ctx, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: _prefs.textScale,
        maxScaleFactor: _prefs.textScale,
        child: child!,
      ),
      home: const AuthGate(),
      debugShowCheckedModeBanner: false,
    );
  }
}

