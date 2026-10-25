import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app_palette.dart';

enum ReminderMode { notification, alarm }

class AppSettings {
  const AppSettings({
    required this.refreshIntervalMinutes,
    required this.remindersEnabled,
    required this.reminderMode,
    required this.reminderLeadMinutes,
    required this.firstWeekStarts,
    required this.cacheReminderEnabled,
    required this.cacheReminderDays,
    required this.themeColor,
    required this.timetableBackgroundValue,
    required this.timetableBackgroundImagePath,
    required this.utilityAlertsEnabled,
    required this.waterAlertThreshold,
    required this.electricityAlertThreshold,
  });

  static const usernameKey = 'username';
  static const selectedTermKey = 'selected_term';
  static const cacheKey = 'schedule_cache_v1';
  static const customCoursesKey = 'custom_courses_v1';
  static const lastUpdatedKey = 'last_updated';
  static const lastErrorKey = 'last_error';
  static const refreshIntervalKey = 'refresh_interval_minutes';
  static const remindersEnabledKey = 'reminders_enabled';
  static const reminderModeKey = 'reminder_mode';
  static const reminderLeadKey = 'reminder_lead_minutes';
  static const firstWeekStartsKey = 'first_week_starts_v1';
  static const cacheReminderEnabledKey = 'cache_reminder_enabled';
  static const cacheReminderDaysKey = 'cache_reminder_days';
  static const themeColorKey = 'theme_color';
  static const timetableBackgroundKey = 'timetable_background';
  static const timetableBackgroundImageKey = 'timetable_background_image';
  static const tasksKey = 'schedule_tasks_v1';
  static const hiddenCoursesKey = 'hidden_courses_v1';
  static const utilitySnapshotKey = 'utility_snapshot_v2';
  static const utilityHistoryKey = 'utility_history_v1';
  static const utilityAlertsEnabledKey = 'utility_alerts_enabled';
  static const waterAlertThresholdKey = 'water_alert_threshold';
  static const electricityAlertThresholdKey = 'electricity_alert_threshold';
  static const utilityAlertLastDayKey = 'utility_alert_last_day';

  final int refreshIntervalMinutes;
  final bool remindersEnabled;
  final ReminderMode reminderMode;
  final int reminderLeadMinutes;
  final Map<String, DateTime> firstWeekStarts;
  final bool cacheReminderEnabled;
  final int cacheReminderDays;
  final AppThemeColor themeColor;
  final int timetableBackgroundValue;
  final String? timetableBackgroundImagePath;
  final bool utilityAlertsEnabled;
  final double waterAlertThreshold;
  final double electricityAlertThreshold;

  static const defaults = AppSettings(
    refreshIntervalMinutes: 60,
    remindersEnabled: true,
    reminderMode: ReminderMode.notification,
    reminderLeadMinutes: 15,
    firstWeekStarts: {},
    cacheReminderEnabled: true,
    cacheReminderDays: 7,
    themeColor: AppThemeColor.white,
    timetableBackgroundValue: 0xFFFFFFFF,
    timetableBackgroundImagePath: null,
    utilityAlertsEnabled: false,
    waterAlertThreshold: 10,
    electricityAlertThreshold: 20,
  );

  factory AppSettings.load(SharedPreferences prefs) {
    final modeName = prefs.getString(reminderModeKey);
    final firstWeekStarts = <String, DateTime>{};
    final firstWeekStartsRaw = prefs.getString(firstWeekStartsKey);
    if (firstWeekStartsRaw != null && firstWeekStartsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(firstWeekStartsRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final value = DateTime.tryParse(entry.value.toString());
            if (value != null) {
              firstWeekStarts[entry.key.toString()] = value;
            }
          }
        }
      } catch (_) {
        firstWeekStarts.clear();
      }
    }
    return AppSettings(
      refreshIntervalMinutes:
          (prefs.getInt(refreshIntervalKey) ?? defaults.refreshIntervalMinutes)
              .clamp(15, 1440),
      remindersEnabled:
          prefs.getBool(remindersEnabledKey) ?? defaults.remindersEnabled,
      reminderMode: ReminderMode.values.firstWhere(
        (mode) => mode.name == modeName,
        orElse: () => defaults.reminderMode,
      ),
      reminderLeadMinutes:
          prefs.getInt(reminderLeadKey) ?? defaults.reminderLeadMinutes,
      firstWeekStarts: firstWeekStarts,
      cacheReminderEnabled:
          prefs.getBool(cacheReminderEnabledKey) ??
          defaults.cacheReminderEnabled,
      cacheReminderDays:
          prefs.getInt(cacheReminderDaysKey) ?? defaults.cacheReminderDays,
      themeColor: AppThemeColor.values.firstWhere(
        (value) => value.name == prefs.getString(themeColorKey),
        orElse: () => defaults.themeColor,
      ),
      timetableBackgroundValue:
          prefs.getInt(timetableBackgroundKey) ??
          defaults.timetableBackgroundValue,
      timetableBackgroundImagePath: prefs.getString(
        timetableBackgroundImageKey,
      ),
      utilityAlertsEnabled:
          prefs.getBool(utilityAlertsEnabledKey) ??
          defaults.utilityAlertsEnabled,
      waterAlertThreshold:
          prefs.getDouble(waterAlertThresholdKey) ??
          defaults.waterAlertThreshold,
      electricityAlertThreshold:
          prefs.getDouble(electricityAlertThresholdKey) ??
          defaults.electricityAlertThreshold,
    );
  }

  AppSettings copyWith({
    int? refreshIntervalMinutes,
    bool? remindersEnabled,
    ReminderMode? reminderMode,
    int? reminderLeadMinutes,
    Map<String, DateTime>? firstWeekStarts,
    bool? cacheReminderEnabled,
    int? cacheReminderDays,
    AppThemeColor? themeColor,
    int? timetableBackgroundValue,
    String? timetableBackgroundImagePath,
    bool clearTimetableBackgroundImage = false,
    bool? utilityAlertsEnabled,
    double? waterAlertThreshold,
    double? electricityAlertThreshold,
  }) {
    return AppSettings(
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderMode: reminderMode ?? this.reminderMode,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      firstWeekStarts: firstWeekStarts ?? this.firstWeekStarts,
      cacheReminderEnabled: cacheReminderEnabled ?? this.cacheReminderEnabled,
      cacheReminderDays: cacheReminderDays ?? this.cacheReminderDays,
      themeColor: themeColor ?? this.themeColor,
      timetableBackgroundValue:
          timetableBackgroundValue ?? this.timetableBackgroundValue,
      timetableBackgroundImagePath: clearTimetableBackgroundImage
          ? null
          : timetableBackgroundImagePath ?? this.timetableBackgroundImagePath,
      utilityAlertsEnabled: utilityAlertsEnabled ?? this.utilityAlertsEnabled,
      waterAlertThreshold: waterAlertThreshold ?? this.waterAlertThreshold,
      electricityAlertThreshold:
          electricityAlertThreshold ?? this.electricityAlertThreshold,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setInt(refreshIntervalKey, refreshIntervalMinutes);
    await prefs.setBool(remindersEnabledKey, remindersEnabled);
    await prefs.setString(reminderModeKey, reminderMode.name);
    await prefs.setInt(reminderLeadKey, reminderLeadMinutes);
    if (firstWeekStarts.isEmpty) {
      await prefs.remove(firstWeekStartsKey);
    } else {
      await prefs.setString(
        firstWeekStartsKey,
        jsonEncode({
          for (final entry in firstWeekStarts.entries)
            entry.key: DateTime(
              entry.value.year,
              entry.value.month,
              entry.value.day,
            ).toIso8601String(),
        }),
      );
    }
    await prefs.setBool(cacheReminderEnabledKey, cacheReminderEnabled);
    await prefs.setInt(cacheReminderDaysKey, cacheReminderDays);
    await prefs.setString(themeColorKey, themeColor.name);
    await prefs.setInt(timetableBackgroundKey, timetableBackgroundValue);
    final backgroundImagePath = timetableBackgroundImagePath;
    if (backgroundImagePath == null || backgroundImagePath.isEmpty) {
      await prefs.remove(timetableBackgroundImageKey);
    } else {
      await prefs.setString(timetableBackgroundImageKey, backgroundImagePath);
    }
    await prefs.setBool(utilityAlertsEnabledKey, utilityAlertsEnabled);
    await prefs.setDouble(waterAlertThresholdKey, waterAlertThreshold);
    await prefs.setDouble(
      electricityAlertThresholdKey,
      electricityAlertThreshold,
    );
  }
}
