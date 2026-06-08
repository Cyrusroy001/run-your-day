import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workmanager/workmanager.dart';
import 'data/store.dart';
import 'screens/home_screen.dart';

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
  await Workmanager().initialize(callbackDispatcher);
  // Android's WorkManager floor is 15 min — this is the real driver of the
  // widget's "live" refresh (the appwidget updatePeriodMillis is capped at 30).
  await Workmanager().registerPeriodicTask(
    _widgetRefreshTask,
    _widgetRefreshTask,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
  );
  runApp(const DailyCommandCenterApp());
}

class DailyCommandCenterApp extends StatelessWidget {
  const DailyCommandCenterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reminders 2',
      theme: _theme(),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _theme() {
    const bg    = Color(0xFF0E1311);
    const panel = Color(0xFF19211D);
    const cream = Color(0xFFF2EDE1);
    const terra = Color(0xFFD9663D);
    const line  = Color(0xFF2C3833);

    return ThemeData(
      colorScheme: const ColorScheme.dark(
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

class AppColors {
  static const bg        = Color(0xFF0E1311);
  static const bg2       = Color(0xFF141B18);
  static const panel     = Color(0xFF19211D);
  static const panel2    = Color(0xFF1F2925);
  static const cream     = Color(0xFFF2EDE1);
  static const terra     = Color(0xFFD9663D);
  static const terraDark = Color(0xFFB8512C);
  static const moss      = Color(0xFF8FB05A);
  static const amber     = Color(0xFFE0A23A);
  static const sky       = Color(0xFF6FA8C7);
  static const line      = Color(0xFF2C3833);
  static const muted     = Color(0xFF8A978F);
  static const dim       = Color(0xFF5E6C64);
}
