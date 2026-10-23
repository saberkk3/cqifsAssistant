import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_palette.dart';
import 'models/course.dart';
import 'models/schedule_task.dart';
import 'services/app_settings.dart';
import 'services/background_service.dart';
import 'services/jw_client.dart';
import 'services/notification_service.dart';
import 'services/schedule_repository.dart';
import 'services/schedule_utils.dart';
import 'services/utility_client.dart';

class AppState extends ChangeNotifier {
  AppState({ScheduleRepository? repository, NotificationService? notifications})
    : repository = repository ?? ScheduleRepository(),
      notifications = notifications ?? NotificationService();

  final ScheduleRepository repository;
  final NotificationService notifications;

  SharedPreferences? _prefs;
  bool _booting = true;
  bool _loggedIn = false;
  bool _refreshing = false;
  bool _sessionExpired = false;
  String? _username;
  String? _error;
  String _term = '';
  List<String> _terms = const [];
  List<Course> _remoteCourses = const [];
  List<Course> _customCourses = const [];
  Set<String> _hiddenCourseIds = {};
  List<ScheduleTask> _tasks = const [];
  UtilitySnapshot? _utilitySnapshot;
  List<UtilityHistoryPoint> _utilityHistory = const [];
  DateTime? _lastUpdated;
  AppSettings _settings = AppSettings.defaults;

  bool get booting => _booting;
  bool get loggedIn => _loggedIn;
  bool get needsLogin => !_loggedIn || _sessionExpired;
  bool get refreshing => _refreshing;
  bool get sessionExpired => _sessionExpired;
  String? get username => _username;
  String? get error => _error;
  String get term => _term;
  List<String> get terms => _terms;
  List<Course> get courses {
    final activeCustom = _customCourses
        .where((course) => course.term.isEmpty || course.term == _term)
        .toList();
    final overrides = <String, Course>{
      for (final course in activeCustom)
        if (course.id?.startsWith('override:') == true) course.id!: course,
    };
    final merged = <Course>[];
    for (final remote in _remoteCourses) {
      final key = courseIdentity(remote);
      final override = overrides.remove('override:$key');
      if (override != null) {
        merged.add(override);
      } else if (!_hiddenCourseIds.contains(key)) {
        merged.add(remote);
      }
    }
    merged.addAll(
      activeCustom.where(
        (course) =>
            course.id?.startsWith('override:') != true ||
            !merged.any((item) => item.id == course.id),
      ),
    );
    final sorted = merged
      ..sort((left, right) {
        final dayCompare = left.weekday.compareTo(right.weekday);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return left.startPeriod.compareTo(right.startPeriod);
      });
    return List.unmodifiable(sorted);
  }

  DateTime? get lastUpdated => _lastUpdated;
  AppSettings get settings => _settings;
  UtilitySnapshot? get utilitySnapshot => _utilitySnapshot;
  List<UtilityHistoryPoint> get utilityHistory =>
      List.unmodifiable(_utilityHistory);
  int get currentWeek => displayedCurrentWeek(_term);
  Color get themePrimary => _settings.themeColor.primary;
  Color get timetableBackground => Color(_settings.timetableBackgroundValue);

  List<ScheduleTask> get tasks {
    final result = [..._tasks]
      ..sort((left, right) => left.startAt.compareTo(right.startAt));
    return List.unmodifiable(result);
  }

  int? get cacheAgeDays {
    final last = _lastUpdated;
    if (last == null) {
      return null;
    }
    return DateTime.now().difference(last).inDays;
  }

  bool get cacheReminderDue {
    final age = cacheAgeDays;
    return _settings.cacheReminderEnabled &&
        age != null &&
        age >= _settings.cacheReminderDays;
  }

  List<Course> get todayCourses {
    final weekday = DateTime.now().weekday;
    return coursesForDay(courses, weekday: weekday, week: currentWeek);
  }

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> bootstrap() async {
    try {
      final prefs = await _preferences;
      _settings = AppSettings.load(prefs);
      _username = prefs.getString(AppSettings.usernameKey);
      await _loadCustomCourses();
      await _loadHiddenCourses();
      await _loadTasks();
      await _loadUtilitySnapshot();
      await _loadUtilityHistory();
      final cached = await repository.loadCachedSnapshot();
      if (cached != null) {
        _applySnapshot(cached);
        _loggedIn = true;
      }

      await notifications.init();
      await _rescheduleReminders();

      // Cancel periodic jobs left by older app versions. This version never
      // performs an automatic network refresh.
      try {
        await BackgroundService.initialize();
        await BackgroundService.cancel();
      } catch (_) {
        // Background scheduling is best-effort.
      }
    } catch (error) {
      _error = _friendlyError(error);
    } finally {
      _booting = false;
      notifyListeners();
    }
  }

  Future<Uint8List> loadCaptcha({bool resetSession = false}) {
    return repository.client.loadCaptcha(resetSession: resetSession);
  }

  Future<void> login({
    required String username,
    required String password,
    required String captcha,
  }) async {
    _error = null;
    final snapshot = await repository.loginAndFetch(
      username: username,
      password: password,
      captcha: captcha,
    );
    final prefs = await _preferences;
    await prefs.setString(AppSettings.usernameKey, username);
    _username = username;
    _loggedIn = true;
    _sessionExpired = false;
    _applySnapshot(snapshot);
    if (_settings.remindersEnabled) {
      await notifications.requestPermissions(_settings.reminderMode);
    } else if (_settings.cacheReminderEnabled) {
      await notifications.requestPermissions(ReminderMode.notification);
    }
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> refreshNow() async {
    await _refresh(showSpinner: true);
  }

  Future<void> selectTerm(String term) async {
    if (term == _term) {
      return;
    }
    final previousTerm = _term;
    final previousTerms = _terms;
    _term = term;
    await _refresh(showSpinner: true);
    if (_error != null && !_sessionExpired) {
      _term = previousTerm;
      _terms = previousTerms;
      notifyListeners();
    }
  }

  Future<String?> setCacheReminderEnabled(bool enabled) async {
    if (enabled) {
      final granted = await notifications.requestPermissions(
        ReminderMode.notification,
      );
      if (!granted) {
        return '未获得通知权限';
      }
    }
    _settings = _settings.copyWith(cacheReminderEnabled: enabled);
    final prefs = await _preferences;
    await _settings.save(prefs);
    await _scheduleCacheReminder();
    notifyListeners();
    return null;
  }

  Future<void> setCacheReminderDays(int days) async {
    final value = days.clamp(1, 90).toInt();
    _settings = _settings.copyWith(cacheReminderDays: value);
    final prefs = await _preferences;
    await _settings.save(prefs);
    await _scheduleCacheReminder();
    notifyListeners();
  }

  Future<void> setThemeColor(AppThemeColor color) async {
    _settings = _settings.copyWith(themeColor: color);
    final prefs = await _preferences;
    await _settings.save(prefs);
    notifyListeners();
  }

  Future<void> setTimetableBackground(Color color) async {
    _settings = _settings.copyWith(timetableBackgroundValue: color.toARGB32());
    final prefs = await _preferences;
    await _settings.save(prefs);
    notifyListeners();
  }

  Future<void> setTimetableBackgroundImage(String? path) async {
    _settings = _settings.copyWith(
      timetableBackgroundImagePath: path,
      clearTimetableBackgroundImage: path == null,
    );
    final prefs = await _preferences;
    await _settings.save(prefs);
    notifyListeners();
  }

  Future<String?> setRemindersEnabled(bool enabled) async {
    if (enabled) {
      final granted = await notifications.requestPermissions(
        _settings.reminderMode,
      );
      if (!granted) {
        return '未获得通知或精确闹钟权限';
      }
    }
    _settings = _settings.copyWith(remindersEnabled: enabled);
    final prefs = await _preferences;
    await _settings.save(prefs);
    await _rescheduleReminders();
    notifyListeners();
    return null;
  }

  Future<String?> setReminderMode(ReminderMode mode) async {
    final granted = await notifications.requestPermissions(mode);
    if (!granted) {
      return '未获得所需提醒权限';
    }
    _settings = _settings.copyWith(reminderMode: mode);
    final prefs = await _preferences;
    await _settings.save(prefs);
    await _rescheduleReminders();
    notifyListeners();
    return null;
  }

  Future<void> setReminderLead(int minutes) async {
    _settings = _settings.copyWith(reminderLeadMinutes: minutes);
    final prefs = await _preferences;
    await _settings.save(prefs);
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<String?> setUtilityAlertsEnabled(bool enabled) async {
    if (enabled) {
      final granted = await notifications.requestPermissions(
        ReminderMode.notification,
      );
      if (!granted) {
        return '未获得通知权限';
      }
    }
    _settings = _settings.copyWith(utilityAlertsEnabled: enabled);
    final prefs = await _preferences;
    await _settings.save(prefs);
    notifyListeners();
    return null;
  }

  Future<void> setWaterAlertThreshold(double value) async {
    _settings = _settings.copyWith(
      waterAlertThreshold: value.clamp(0, 10000).toDouble(),
    );
    final prefs = await _preferences;
    await _settings.save(prefs);
    notifyListeners();
  }

  Future<void> setElectricityAlertThreshold(double value) async {
    _settings = _settings.copyWith(
      electricityAlertThreshold: value.clamp(0, 10000).toDouble(),
    );
    final prefs = await _preferences;
    await _settings.save(prefs);
    notifyListeners();
  }

  Future<void> requireLogin() async {
    _loggedIn = false;
    notifyListeners();
  }

  Future<void> logout() async {
    await repository.clearSession();
    await notifications.cancelAll();
    await BackgroundService.cancel();
    _loggedIn = false;
    _sessionExpired = false;
    _username = null;
    _term = '';
    _terms = const [];
    _remoteCourses = const [];
    _customCourses = const [];
    _hiddenCourseIds = {};
    _tasks = const [];
    _utilitySnapshot = null;
    _utilityHistory = const [];
    _lastUpdated = null;
    _error = null;
    final prefs = await _preferences;
    await prefs.remove(AppSettings.customCoursesKey);
    await prefs.remove(AppSettings.hiddenCoursesKey);
    await prefs.remove(AppSettings.tasksKey);
    await prefs.remove(AppSettings.utilitySnapshotKey);
    await prefs.remove(AppSettings.utilityHistoryKey);
    await prefs.remove(AppSettings.utilityAlertLastDayKey);
    notifyListeners();
  }

  Future<void> saveUtilitySnapshot(UtilitySnapshot snapshot) async {
    _utilitySnapshot = snapshot;
    final point = UtilityHistoryPoint(
      waterRemaining: snapshot.waterRemaining,
      electricityRemaining: snapshot.electricityRemaining,
      waterBalance: snapshot.waterBalance,
      electricityBalance: snapshot.electricityBalance,
      recordedAt: snapshot.updatedAt,
    );
    final last = _utilityHistory.isEmpty ? null : _utilityHistory.last;
    if (last == null ||
        point.recordedAt.difference(last.recordedAt) >=
            const Duration(minutes: 10)) {
      _utilityHistory = [..._utilityHistory, point];
      if (_utilityHistory.length > 180) {
        _utilityHistory = _utilityHistory.sublist(_utilityHistory.length - 180);
      }
    }
    final prefs = await _preferences;
    await prefs.setString(
      AppSettings.utilitySnapshotKey,
      jsonEncode(snapshot.toJson()),
    );
    await prefs.setString(
      AppSettings.utilityHistoryKey,
      jsonEncode(_utilityHistory.map((item) => item.toJson()).toList()),
    );
    await _checkUtilityAlerts(snapshot);
    notifyListeners();
  }

  Future<void> saveTask(ScheduleTask task) async {
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) {
      _tasks[index] = task;
    } else {
      _tasks = [..._tasks, task];
    }
    await _persistTasks();
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    _tasks = _tasks.where((task) => task.id != id).toList();
    await notifications.cancelTaskReminder(id);
    await _persistTasks();
    notifyListeners();
  }

  Future<void> saveCustomCourse(Course course) async {
    final index = _customCourses.indexWhere((item) => item.id == course.id);
    if (index >= 0) {
      _customCourses[index] = course;
    } else {
      _customCourses = [..._customCourses, course];
    }
    await _persistCustomCourses();
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> deleteCustomCourse(String id) async {
    _customCourses = _customCourses.where((course) => course.id != id).toList();
    await _persistCustomCourses();
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> saveCourseChange({
    required Course original,
    required Course updated,
  }) async {
    if (original.isCustom) {
      final index = _customCourses.indexWhere((item) => item.id == original.id);
      final replacement = _rebuildCourse(updated, id: original.id!);
      if (index >= 0) {
        _customCourses[index] = replacement;
      } else {
        _customCourses = [..._customCourses, replacement];
      }
    } else {
      final sourceKey = courseIdentity(original);
      final overrideId = 'override:$sourceKey';
      _hiddenCourseIds.add(sourceKey);
      _customCourses = _customCourses
          .where((item) => item.id != overrideId)
          .toList();
      _customCourses = [
        ..._customCourses,
        _rebuildCourse(updated, id: overrideId, fallbackTerm: original.term),
      ];
    }
    await _persistCustomCourses();
    await _persistHiddenCourses();
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> deleteCourse(Course course) async {
    if (course.isCustom) {
      final id = course.id;
      _customCourses = _customCourses.where((item) => item.id != id).toList();
      if (id?.startsWith('override:') == true) {
        _hiddenCourseIds.add(id!.substring('override:'.length));
      }
    } else {
      _hiddenCourseIds.add(courseIdentity(course));
    }
    await _persistCustomCourses();
    await _persistHiddenCourses();
    await _rescheduleReminders();
    notifyListeners();
  }

  Future<void> _refresh({required bool showSpinner}) async {
    if (_refreshing) {
      return;
    }
    _refreshing = showSpinner;
    _error = null;
    notifyListeners();
    try {
      final snapshot = await repository.fetchSchedule(
        term: _term.isEmpty ? null : _term,
      );
      _applySnapshot(snapshot);
      _sessionExpired = false;
      _loggedIn = true;
      await _rescheduleReminders();
    } on SessionExpiredException catch (error) {
      _sessionExpired = true;
      _error = error.toString();
      if (courses.isEmpty) {
        _loggedIn = false;
      }
    } catch (error) {
      _error = _friendlyError(error);
      if (courses.isEmpty) {
        _loggedIn = false;
      }
    } finally {
      _refreshing = false;
      notifyListeners();
    }
  }

  void _applySnapshot(ScheduleSnapshot snapshot) {
    _term = snapshot.term;
    _terms = snapshot.terms;
    _remoteCourses = snapshot.courses;
    _lastUpdated = snapshot.fetchedAt;
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(prefs.setString(AppSettings.selectedTermKey, snapshot.term));
      unawaited(
        prefs.setString(
          AppSettings.lastUpdatedKey,
          snapshot.fetchedAt.toIso8601String(),
        ),
      );
    }
  }

  Future<void> _rescheduleReminders() async {
    try {
      await notifications.scheduleCourseReminders(
        courses: courses,
        term: _term,
        settings: _settings,
      );
      await notifications.scheduleTaskReminders(_tasks);
    } catch (_) {
      // Course reminder scheduling should not block timetable updates.
    }
    await _scheduleCacheReminder();
  }

  Future<void> _scheduleCacheReminder() async {
    try {
      await notifications.scheduleCacheReminder(
        lastUpdated: _lastUpdated,
        enabled: _settings.cacheReminderEnabled,
        days: _settings.cacheReminderDays,
      );
    } catch (_) {
      // Cache reminder scheduling is best-effort.
    }
  }

  Future<void> _loadCustomCourses() async {
    final prefs = await _preferences;
    final raw = prefs.getString(AppSettings.customCoursesKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      _customCourses = values
          .map((item) => Course.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _customCourses = const [];
    }
  }

  Future<void> _persistCustomCourses() async {
    final prefs = await _preferences;
    await prefs.setString(
      AppSettings.customCoursesKey,
      jsonEncode(_customCourses.map((course) => course.toJson()).toList()),
    );
  }

  Course _rebuildCourse(
    Course source, {
    required String id,
    String? fallbackTerm,
  }) {
    return Course(
      id: id,
      name: source.name,
      teacher: source.teacher,
      location: source.location,
      weekday: source.weekday,
      startPeriod: source.startPeriod,
      endPeriod: source.endPeriod,
      weeks: source.weeks,
      term: source.term.isEmpty ? fallbackTerm ?? _term : source.term,
      timeText: source.timeText,
      displayTime: source.displayTime,
      weekPeriodRaw: source.weekPeriodRaw,
      isCustom: true,
      colorValue: source.colorValue,
    );
  }

  Future<void> _loadHiddenCourses() async {
    final prefs = await _preferences;
    final raw = prefs.getString(AppSettings.hiddenCoursesKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      _hiddenCourseIds = (jsonDecode(raw) as List<dynamic>)
          .map((item) => item.toString())
          .toSet();
    } catch (_) {
      _hiddenCourseIds = {};
    }
  }

  Future<void> _persistHiddenCourses() async {
    final prefs = await _preferences;
    await prefs.setString(
      AppSettings.hiddenCoursesKey,
      jsonEncode(_hiddenCourseIds.toList()),
    );
  }

  Future<void> _loadTasks() async {
    final prefs = await _preferences;
    final raw = prefs.getString(AppSettings.tasksKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      _tasks = values
          .map((item) => ScheduleTask.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _tasks = const [];
    }
  }

  Future<void> _loadUtilitySnapshot() async {
    final prefs = await _preferences;
    final raw = prefs.getString(AppSettings.utilitySnapshotKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) {
        _utilitySnapshot = UtilitySnapshot.fromJson(value);
      } else if (value is Map) {
        _utilitySnapshot = UtilitySnapshot.fromJson(
          value.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      _utilitySnapshot = null;
    }
  }

  Future<void> _loadUtilityHistory() async {
    final prefs = await _preferences;
    final raw = prefs.getString(AppSettings.utilityHistoryKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final values = jsonDecode(raw) as List<dynamic>;
      _utilityHistory = values
          .whereType<Map>()
          .map(
            (item) => UtilityHistoryPoint.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } catch (_) {
      _utilityHistory = const [];
    }
  }

  Future<void> _checkUtilityAlerts(UtilitySnapshot snapshot) async {
    if (!_settings.utilityAlertsEnabled) {
      return;
    }
    final lowWater = snapshot.waterBalance <= _settings.waterAlertThreshold;
    final lowElectricity =
        snapshot.electricityBalance <= _settings.electricityAlertThreshold;
    if (!lowWater && !lowElectricity) {
      return;
    }
    final prefs = await _preferences;
    final today =
        '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (prefs.getString(AppSettings.utilityAlertLastDayKey) == today) {
      return;
    }
    final lines = <String>[];
    if (lowWater) {
      lines.add(
        '水费余额 ¥${snapshot.waterBalance.toStringAsFixed(2)}'
        '（阈值 ¥${_settings.waterAlertThreshold.toStringAsFixed(2)}）',
      );
    }
    if (lowElectricity) {
      lines.add(
        '电费余额 ¥${snapshot.electricityBalance.toStringAsFixed(2)}'
        '（阈值 ¥${_settings.electricityAlertThreshold.toStringAsFixed(2)}）',
      );
    }
    await notifications.showUtilityBalanceAlert(lines.join('\n'));
    await prefs.setString(AppSettings.utilityAlertLastDayKey, today);
  }

  Future<void> _persistTasks() async {
    final prefs = await _preferences;
    await prefs.setString(
      AppSettings.tasksKey,
      jsonEncode(_tasks.map((task) => task.toJson()).toList()),
    );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (error is LoginException || error is SessionExpiredException) {
      return text;
    }
    if (text.contains('SocketException') || text.contains('Connection')) {
      return '网络连接失败，请检查网络后重试';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
