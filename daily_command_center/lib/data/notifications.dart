import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Dedicated high-priority channel for circuit-breaker (auto-cancel) alerts.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static const String _channelId = 'drift_breaker';
  static const String _channelName = 'Schedule auto-cancels';
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId, _channelName,
      description: 'Fires when the engine auto-cancels a drifted block to protect your evening.',
      importance: Importance.high,
      playSound: true,
    ));
    await androidImpl?.requestNotificationsPermission();
    _ready = true;
  }

  static Future<void> fireBreach(String title, String body, {int id = 1001}) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId, _channelName,
        importance: Importance.high, priority: Priority.high, playSound: true,
      ),
    );
    await _plugin.show(id, title, body, details);
  }
}
