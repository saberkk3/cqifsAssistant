import 'package:home_widget/home_widget.dart';

import '../models/course.dart';
import '../models/schedule_task.dart';
import 'schedule_utils.dart';
import 'utility_client.dart';

class HomeWidgetService {
  static const _androidProvider = 'TodayWidgetProvider';
  static const _qualifiedProvider =
      'com.cqwywsxy.timetable_app.TodayWidgetProvider';

  static Future<void> update({
    required List<Course> courses,
    required List<ScheduleTask> tasks,
    required int week,
    required DateTime now,
    UtilitySnapshot? utility,
  }) async {
    try {
      final todayCourses = coursesForDay(
        courses,
        weekday: now.weekday,
        week: week,
      );
      final courseText = todayCourses.isEmpty
          ? '今天没有课程'
          : todayCourses
                .take(4)
                .map(
                  (course) =>
                      '${clockTimeLabel(course)}  ${course.name}'
                      '${course.location == '未标注' ? '' : ' · ${course.location}'}',
                )
                .join('\n');
      final activeTasks = tasks
          .where((task) => task.endAt.isAfter(now))
          .take(3)
          .toList();
      final taskText = activeTasks.isEmpty
          ? '暂无待办日程'
          : activeTasks
                .map((task) => '${task.title} · ${task.countdownLabel(now)}')
                .join('\n');
      final waterText = utility == null
          ? '水表  未授权'
          : '水表  ${utility.waterRemaining.toStringAsFixed(2)}吨'
                ' / ¥${utility.waterBalance.toStringAsFixed(2)}';
      final electricityText = utility == null
          ? '电表  未授权'
          : '电表  ${utility.electricityRemaining.toStringAsFixed(2)}度'
                ' / ¥${utility.electricityBalance.toStringAsFixed(2)}';

      await HomeWidget.saveWidgetData<String>(
        'widget_date',
        '${now.month}月${now.day}日 ${weekdayLongLabel(now.weekday)}',
      );
      await HomeWidget.saveWidgetData<String>('widget_week', '第$week周');
      await HomeWidget.saveWidgetData<String>('widget_courses', courseText);
      await HomeWidget.saveWidgetData<String>('widget_tasks', taskText);
      await HomeWidget.saveWidgetData<String>('widget_water', waterText);
      await HomeWidget.saveWidgetData<String>(
        'widget_electricity',
        electricityText,
      );
      await HomeWidget.saveWidgetData<String>(
        'widget_updated',
        '更新 ${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}',
      );
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
        qualifiedAndroidName: _qualifiedProvider,
      );
    } catch (_) {
      // Widgets are optional and should never block the main app.
    }
  }
}
