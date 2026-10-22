import '../models/course.dart';

const weekdayNames = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

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
  final displayTimeMatch = RegExp(r'(\d{1,2}):(\d{2})')
      .firstMatch(course.displayTime);
  if (displayTimeMatch != null) {
    final hour = int.tryParse(displayTimeMatch.group(1) ?? '');
    final minute = int.tryParse(displayTimeMatch.group(2) ?? '');
    if (hour != null && minute != null) {
      return DateTime(date.year, date.month, date.day, hour, minute);
    }
  }
  final basePeriod = course.startPeriod.isEven
      ? course.startPeriod - 1
      : course.startPeriod;
  final hourMinute = switch (basePeriod) {
    1 => const (8, 30),
    3 => const (10, 25),
    5 => const (12, 45),
    7 => const (14, 30),
    9 => const (16, 25),
    11 => const (19, 0),
    13 => const (20, 40),
    _ => const (8, 30),
  };
  return DateTime(
    date.year,
    date.month,
    date.day,
    hourMinute.$1,
    hourMinute.$2,
  );
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
