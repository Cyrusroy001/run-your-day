import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../logic/heads_up.dart';

/// Notifications: the circuit-breaker auto-cancel alert (high priority) and the
/// opt-in ketchup heads-up + Sunday nudge (one quiet heads-up per block — the
/// only notifications ketchup ever sends). Inexact alarms (no exact-alarm
/// permission needed); rescheduled whenever the app resolves a day.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const String _breakerId = 'drift_breaker';
  static const String _headsUpId = 'heads_up';
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // Cyrus is in Pune; default to IST. (Future multi-user: read plan.meta.timezone.)
    try { tz.setLocalLocation(tz.getLocation('Asia/Kolkata')); } catch (_) {}
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
    final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await a?.createNotificationChannel(const AndroidNotificationChannel(
      _breakerId, 'Schedule auto-cancels',
      description: 'Fires when a drifted block is auto-cancelled to protect your evening.',
      importance: Importance.high, playSound: true));
    await a?.createNotificationChannel(const AndroidNotificationChannel(
      _headsUpId, 'Heads-up before each block',
      description: 'One quiet heads-up before a block — that is all ketchup sends.',
      importance: Importance.defaultImportance));
    await a?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> fireBreach(String title, String body, {int id = 1001}) async {
    await init();
    const details = NotificationDetails(android: AndroidNotificationDetails(
      _breakerId, 'Schedule auto-cancels',
      importance: Importance.high, priority: Priority.high, playSound: true));
    await _plugin.show(id, title, body, details);
  }

  /// Cancel the reserved heads-up id range, then schedule [ups] (no-op list = a
  /// clean cancel — used when the toggle is off).
  static Future<void> scheduleHeadsUps(List<HeadsUp> ups) async {
    await init();
    for (var id = headsUpIdBase; id <= headsUpIdMax; id++) {
      await _plugin.cancel(id);
    }
    const details = NotificationDetails(android: AndroidNotificationDetails(
      _headsUpId, 'Heads-up before each block', importance: Importance.defaultImportance));
    for (final u in ups) {
      await _plugin.zonedSchedule(
        u.id, u.title, u.body, tz.TZDateTime.from(u.when, tz.local), details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
    }
  }

  /// Weekly Sunday 7 pm "your catch-up is ready" nudge — scheduled when [on],
  /// cancelled otherwise.
  static Future<void> scheduleSundayNudge(bool on) async {
    await init();
    await _plugin.cancel(sundayNudgeId);
    if (!on) return;
    const details = NotificationDetails(android: AndroidNotificationDetails(
      _headsUpId, 'Heads-up before each block', importance: Importance.defaultImportance));
    await _plugin.zonedSchedule(
      sundayNudgeId, 'Your Sunday catch-up is ready.', '', _nextSunday7pm(), details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime);
  }

  static tz.TZDateTime _nextSunday7pm() {
    final now = tz.TZDateTime.now(tz.local);
    var d = tz.TZDateTime(tz.local, now.year, now.month, now.day, 19);
    while (d.weekday != DateTime.sunday || !d.isAfter(now)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }
}
