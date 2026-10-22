import 'package:shared_preferences/shared_preferences.dart';

import '../app_palette.dart';

enum ReminderMode { notification, alarm }

class AppSettings {
  const AppSettings({
    required this.refreshIntervalMinutes,
    required this.remindersEnabled,
    required this.reminderMode,
    required this.reminderLeadMinutes,
    required this.cacheReminderEnabled,
    required this.cacheReminderDays,
    required this.themeColor,
    required this.timetableBackgroundValue,
    required this.timetableBackgroundImagePath,
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
  static const cacheReminderEnabledKey = 'cache_reminder_enabled';
  static const cacheReminderDaysKey = 'cache_reminder_days';
  static const themeColorKey = 'theme_color';
  static const timetableBackgroundKey = 'timetable_background';
  static const timetableBackgroundImageKey = 'timetable_background_image';
  static const tasksKey = 'schedule_tasks_v1';
  static const hiddenCoursesKey = 'hidden_courses_v1';
  static const utilitySnapshotKey = 'utility_snapshot_v2';

  final int refreshIntervalMinutes;
  final bool remindersEnabled;
  final ReminderMode reminderMode;
  final int reminderLeadMinutes;
  final bool cacheReminderEnabled;
  final int cacheReminderDays;
  final AppThemeColor themeColor;
  final int timetableBackgroundValue;
  final String? timetableBackgroundImagePath;

  static const defaults = AppSettings(
    refreshIntervalMinutes: 60,
    remindersEnabled: true,
    reminderMode: ReminderMode.notification,
    reminderLeadMinutes: 15,
    cacheReminderEnabled: true,
    cacheReminderDays: 7,
    themeColor: AppThemeColor.white,
    timetableBackgroundValue: 0xFFFFFFFF,
    timetableBackgroundImagePath: null,
  );

  factory AppSettings.load(SharedPreferences prefs) {
    final modeName = prefs.getString(reminderModeKey);
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
    );
  }

  AppSettings copyWith({
    int? refreshIntervalMinutes,
    bool? remindersEnabled,
    ReminderMode? reminderMode,
    int? reminderLeadMinutes,
    bool? cacheReminderEnabled,
    int? cacheReminderDays,
    AppThemeColor? themeColor,
    int? timetableBackgroundValue,
    String? timetableBackgroundImagePath,
    bool clearTimetableBackgroundImage = false,
  }) {
    return AppSettings(
      refreshIntervalMinutes:
          refreshIntervalMinutes ?? this.refreshIntervalMinutes,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderMode: reminderMode ?? this.reminderMode,
      reminderLeadMinutes: reminderLeadMinutes ?? this.reminderLeadMinutes,
      cacheReminderEnabled: cacheReminderEnabled ?? this.cacheReminderEnabled,
      cacheReminderDays: cacheReminderDays ?? this.cacheReminderDays,
      themeColor: themeColor ?? this.themeColor,
      timetableBackgroundValue:
          timetableBackgroundValue ?? this.timetableBackgroundValue,
      timetableBackgroundImagePath: clearTimetableBackgroundImage
          ? null
          : timetableBackgroundImagePath ?? this.timetableBackgroundImagePath,
    );
  }

  Future<void> save(SharedPreferences prefs) async {
    await prefs.setInt(refreshIntervalKey, refreshIntervalMinutes);
    await prefs.setBool(remindersEnabledKey, remindersEnabled);
    await prefs.setString(reminderModeKey, reminderMode.name);
    await prefs.setInt(reminderLeadKey, reminderLeadMinutes);
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
  }
}
