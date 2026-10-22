import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/course.dart';
import 'app_settings.dart';
import 'jw_client.dart';

class ScheduleRepository {
  ScheduleRepository({JwClient? client}) : client = client ?? JwClient();

  final JwClient client;

  Future<ScheduleSnapshot?> loadCachedSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppSettings.cacheKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return ScheduleSnapshot.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSnapshot(ScheduleSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppSettings.cacheKey, jsonEncode(snapshot.toJson()));
    await prefs.setString(AppSettings.selectedTermKey, snapshot.term);
    await prefs.setString(
      AppSettings.lastUpdatedKey,
      snapshot.fetchedAt.toIso8601String(),
    );
  }

  Future<ScheduleSnapshot> fetchSchedule({String? term}) async {
    final snapshot = await client.fetchSchedule(term: term);
    await saveSnapshot(snapshot);
    return snapshot;
  }

  Future<ScheduleSnapshot> loginAndFetch({
    required String username,
    required String password,
    required String captcha,
  }) async {
    await client.login(
      username: username,
      password: password,
      captcha: captcha,
    );
    final snapshot = await client.fetchSchedule();
    await saveSnapshot(snapshot);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppSettings.usernameKey, username);
    return snapshot;
  }

  Future<void> clearSession() async {
    await client.clearSession();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppSettings.usernameKey);
    await prefs.remove(AppSettings.cacheKey);
    await prefs.remove(AppSettings.selectedTermKey);
    await prefs.remove(AppSettings.lastUpdatedKey);
    await prefs.remove(AppSettings.lastErrorKey);
  }
}
