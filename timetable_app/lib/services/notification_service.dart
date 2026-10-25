import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/course.dart';
import '../models/schedule_task.dart';
import 'app_settings.dart';
import 'schedule_utils.dart';

class NotificationService {
  static const _cacheReminderId = 990001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    tz_data.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermissions(ReminderMode mode) async {
    await init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final notificationGranted =
        await android?.requestNotificationsPermission() ?? true;
    final exactGranted = await android?.requestExactAlarmsPermission() ?? true;
    if (mode == ReminderMode.alarm) {
      await android?.requestFullScreenIntentPermission();
    }
    return notificationGranted && exactGranted;
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  Future<void> showUtilityBalanceAlert(String details) async {
    await init();
    await _plugin.show(
      id: 990002,
      title: '水电余额偏低',
      body: details,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'utility_balance',
          '水电余额预警',
          channelDescription: '水费或电费余额低于设定值时提醒',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  Future<void> scheduleCacheReminder({
    required DateTime? lastUpdated,
    required bool enabled,
    required int days,
  }) async {
    await init();
    await _plugin.cancel(id: _cacheReminderId);
    if (!enabled || lastUpdated == null) {
      return;
    }
    final now = DateTime.now();
    final dueAt = lastUpdated.add(Duration(days: days));
    final scheduledAt = dueAt.isBefore(now)
        ? now.add(const Duration(minutes: 1))
        : dueAt;
    await _plugin.zonedSchedule(
      id: _cacheReminderId,
      title: '课表缓存需要更新',
      body: '本地课表已缓存 $days 天，建议打开 App 重新登录刷新。',
      scheduledDate: _localScheduleDate(scheduledAt),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'cache_update',
          '课表缓存提醒',
          channelDescription: '提醒定期重新登录更新本地课表',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> scheduleTaskReminders(List<ScheduleTask> tasks) async {
    await init();
    final now = DateTime.now();
    for (final task in tasks) {
      final id = _taskNotificationId(task.id);
      await _plugin.cancel(id: id);
      if (!task.hasReminder || task.startAt.isBefore(now)) {
        continue;
      }
      final notifyAt = task.startAt.subtract(
        Duration(minutes: task.reminderMinutes),
      );
      if (notifyAt.isBefore(now)) {
        continue;
      }
      final imagePath = task.imagePath;
      final hasImage =
          imagePath != null &&
          imagePath.isNotEmpty &&
          File(imagePath).existsSync();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          'task_reminder',
          '作业与日程提醒',
          channelDescription: '自定义日程开始前提醒',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          largeIcon: hasImage ? FilePathAndroidBitmap(imagePath) : null,
          styleInformation: hasImage
              ? BigPictureStyleInformation(
                  FilePathAndroidBitmap(imagePath),
                  largeIcon: FilePathAndroidBitmap(imagePath),
                  contentTitle: task.title,
                  summaryText: task.note,
                  showBigPictureWhenCollapsed: true,
                )
              : null,
        ),
      );
      await _plugin.zonedSchedule(
        id: id,
        title: '日程提醒 · ${task.title}',
        body: task.note.isEmpty ? '日程即将开始' : task.note,
        scheduledDate: _localScheduleDate(notifyAt),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: task.id,
      );
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    await init();
    await _plugin.cancel(id: _taskNotificationId(taskId));
  }

  int _taskNotificationId(String taskId) {
    return ('task|$taskId').hashCode & 0x7fffffff;
  }

  Future<int> scheduleCourseReminders({
    required List<Course> courses,
    required String term,
    required AppSettings settings,
    DateTime? firstWeekStart,
  }) async {
    await init();
    await _plugin.cancelAll();
    if (!settings.remindersEnabled || term.isEmpty) {
      return 0;
    }

    final now = DateTime.now();
    var scheduled = 0;
    for (var offset = 0; offset < 7; offset++) {
      final date = dateOnly(now).add(Duration(days: offset));
      final week = weekNumberForDate(
        term,
        date,
        firstWeekStart: firstWeekStart,
      );
      if (week == null) {
        continue;
      }
      for (final course in coursesForDay(
        courses,
        weekday: date.weekday,
        week: week,
      )) {
        final start = courseStartTime(date, course);
        if (start == null) {
          continue;
        }
        final notifyAt = start.subtract(
          Duration(minutes: settings.reminderLeadMinutes),
        );
        if (notifyAt.isBefore(now)) {
          continue;
        }
        final isAlarm = settings.reminderMode == ReminderMode.alarm;
        final details = NotificationDetails(
          android: AndroidNotificationDetails(
            isAlarm ? 'course_alarm' : 'course_notice',
            isAlarm ? '上课闹钟' : '上课通知',
            channelDescription: isAlarm ? '重要上课闹钟提醒' : '课程通知栏提醒',
            importance: Importance.max,
            priority: Priority.high,
            category: isAlarm
                ? AndroidNotificationCategory.alarm
                : AndroidNotificationCategory.reminder,
            fullScreenIntent: isAlarm,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
          ),
        );
        final id = _notificationId(course, date);
        await _plugin.zonedSchedule(
          id: id,
          title: '该上课了 · ${course.name}',
          body:
              '${settings.reminderLeadMinutes} 分钟后上课'
              ' · ${course.location} · ${course.teacher}',
          scheduledDate: _localScheduleDate(notifyAt),
          notificationDetails: details,
          androidScheduleMode: isAlarm
              ? AndroidScheduleMode.alarmClock
              : AndroidScheduleMode.exactAllowWhileIdle,
          payload: course.name,
        );
        scheduled++;
      }
    }
    return scheduled;
  }

  int _notificationId(Course course, DateTime date) {
    final source =
        '${course.term}|${course.name}|${course.weekday}|'
        '${course.startPeriod}|${date.year}-${date.month}-${date.day}';
    return source.hashCode & 0x7fffffff;
  }

  tz.TZDateTime _localScheduleDate(DateTime value) {
    return tz.TZDateTime(
      tz.local,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
    );
  }
}
