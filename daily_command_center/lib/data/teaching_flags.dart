import 'package:shared_preferences/shared_preferences.dart';

/// One-time "I've shown you this concept" flags, keyed `taught_<concept>`.
class TeachingFlags {
  static String _key(String concept) => 'taught_$concept';

  static Future<bool> seen(String concept) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(concept)) ?? false;
  }

  static Future<void> markSeen(String concept) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(concept), true);
  }
}
