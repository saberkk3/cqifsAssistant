import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/inspiration_entry.dart';

class InspirationStore {
  static const _storageKey = 'daily_inspiration_entries_v1';

  Future<List<InspirationEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final values = jsonDecode(raw);
      if (values is! List) {
        return const [];
      }
      final entries = values
          .whereType<Map>()
          .map(
            (item) => InspirationEntry.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((entry) => entry.content.trim().isNotEmpty)
          .toList();
      entries.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<InspirationEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}
