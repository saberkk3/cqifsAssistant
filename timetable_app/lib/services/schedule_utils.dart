import '../models/course.dart';

const weekdayNames = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

const periodSchedule = [
  (8, 0, 8, 45),
  (8, 55, 9, 40),
  (10, 10, 10, 55),
  (11, 5, 11, 50),
  (14, 0, 14, 45),
  (14, 55, 15, 40),
  (16, 0, 16, 45),
  (16, 55, 17, 40),
  (19, 0, 19, 45),
  (19, 55, 20, 40),
  (20, 50, 21, 35),
  (21, 45, 22, 30),
  (22, 40, 23, 25),
];

String weekdayShortLabel(int weekday) {
  const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  if (weekday < 1 || weekday > 7) {
    return '';
  }
  return labels[weekday - 1];
}

String weekdayLongLabel(int weekday) {
  if (weekday < 1 || weekday > 7) {
    return '';
  }
  return weekdayNames[weekday - 1];
}

DateTime dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _firstMondayOnOrAfter(DateTime value) {
  final date = dateOnly(value);
  return date.add(Duration(days: (8 - date.weekday) % 7));
}

DateTime? termStartDate(String term) {
  final parts = term.split('-');
  if (parts.length != 3) {
    return null;
  }
  final startYear = int.tryParse(parts[0]);
  final endYear = int.tryParse(parts[1]);
  final semester = int.tryParse(parts[2]);
  if (startYear == null || endYear == null || semester == null) {
    return null;
  }
  if (semester == 1) {
    return _firstMondayOnOrAfter(DateTime(startYear, 9, 1));
  }
  return _firstMondayOnOrAfter(DateTime(endYear, 2, 20));
}

int? weekNumberForDate(String term, DateTime date) {
  final start = termStartDate(term);
  if (start == null) {
    return null;
  }
  final difference = dateOnly(date).difference(start).inDays;
  if (difference < 0) {
    return null;
  }
  final week = difference ~/ 7 + 1;
  if (week < 1 || week > 30) {
    return null;
  }
  return week;
}

int displayedCurrentWeek(String term) {
  return weekNumberForDate(term, DateTime.now()) ?? 1;
}

List<Course> coursesForDay(
  List<Course> courses, {
  required int weekday,
  required int week,
}) {
  final result = courses
      .where((course) => course.weekday == weekday && course.occursInWeek(week))
      .toList();
  result.sort((left, right) => left.startPeriod.compareTo(right.startPeriod));
  return result;
}

DateTime? courseStartTime(DateTime date, Course course) {
  final displayStart = _timeFromText(course.displayTime);
  final textStart = _timeFromText(course.timeText);
  // The school's exported display time can lag behind the real bell schedule.
  // Official courses therefore use the authoritative period table; only
  // user-created courses may override it with a custom clock time.
  final parsedStart = course.isCustom ? displayStart ?? textStart : null;
  if (parsedStart != null) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      parsedStart.$1,
      parsedStart.$2,
    );
  }
  final periodIndex = (course.startPeriod - 1)
      .clamp(0, periodSchedule.length - 1)
      .toInt();
  final period = periodSchedule[periodIndex];
  return DateTime(date.year, date.month, date.day, period.$1, period.$2);
}

(int, int)? _timeFromText(String text) {
  for (final match in RegExp(r'(\d{1,2}):(\d{2})').allMatches(text)) {
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      continue;
    }
    return (hour, minute);
  }
  return null;
}

String periodTimeRange(int period) {
  if (period < 1 || period > periodSchedule.length) {
    return '';
  }
  final value = periodSchedule[period - 1];
  String format(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  return '${format(value.$1, value.$2)}-${format(value.$3, value.$4)}';
}

String clockTimeLabel(Course course) {
  final value = courseStartTime(DateTime(2000, 1, 1), course);
  if (value == null) {
    return '';
  }
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
