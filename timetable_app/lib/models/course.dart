class Course {
  const Course({
    this.id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.weeks,
    required this.term,
    required this.timeText,
    required this.displayTime,
    required this.weekPeriodRaw,
    this.isCustom = false,
    this.colorValue,
  });

  final String? id;
  final String name;
  final String teacher;
  final String location;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final List<int> weeks;
  final String term;
  final String timeText;
  final String displayTime;
  final String weekPeriodRaw;
  final bool isCustom;
  final int? colorValue;

  bool occursInWeek(int week) => weeks.isEmpty || weeks.contains(week);

  String get periodLabel {
    if (startPeriod == endPeriod) {
      return '第$startPeriod节';
    }
    return '第$startPeriod-$endPeriod节';
  }

  String get weeksLabel {
    if (weeks.isEmpty) {
      return '全学期';
    }
    final sorted = [...weeks]..sort();
    final parts = <String>[];
    int start = sorted.first;
    int previous = start;

    for (final week in sorted.skip(1)) {
      if (week == previous + 1) {
        previous = week;
        continue;
      }
      parts.add(start == previous ? '$start周' : '$start-$previous周');
      start = week;
      previous = week;
    }
    parts.add(start == previous ? '$start周' : '$start-$previous周');
    return parts.join('、');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'location': location,
      'weekday': weekday,
      'startPeriod': startPeriod,
      'endPeriod': endPeriod,
      'weeks': weeks,
      'term': term,
      'timeText': timeText,
      'displayTime': displayTime,
      'weekPeriodRaw': weekPeriodRaw,
      'isCustom': isCustom,
      'colorValue': colorValue,
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '未标注',
      location: json['location'] as String? ?? '未标注',
      weekday: json['weekday'] as int? ?? 1,
      startPeriod: json['startPeriod'] as int? ?? 1,
      endPeriod: json['endPeriod'] as int? ?? 2,
      weeks: (json['weeks'] as List<dynamic>? ?? const [])
          .map((item) => item as int)
          .toList(),
      term: json['term'] as String? ?? '',
      timeText: json['timeText'] as String? ?? '',
      displayTime: json['displayTime'] as String? ?? '',
      weekPeriodRaw: json['weekPeriodRaw'] as String? ?? '',
      isCustom: json['isCustom'] as bool? ?? false,
      colorValue: json['colorValue'] as int?,
    );
  }
}

String courseIdentity(Course course) {
  return [
    course.term,
    course.name,
    course.weekday,
    course.startPeriod,
    course.endPeriod,
    course.location,
    course.teacher,
    course.weekPeriodRaw,
  ].join('|');
}

class ScheduleSnapshot {
  const ScheduleSnapshot({
    required this.term,
    required this.terms,
    required this.courses,
    required this.fetchedAt,
  });

  final String term;
  final List<String> terms;
  final List<Course> courses;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() {
    return {
      'term': term,
      'terms': terms,
      'courses': courses.map((course) => course.toJson()).toList(),
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  factory ScheduleSnapshot.fromJson(Map<String, dynamic> json) {
    return ScheduleSnapshot(
      term: json['term'] as String? ?? '',
      terms: (json['terms'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(),
      courses: (json['courses'] as List<dynamic>? ?? const [])
          .map((item) => Course.fromJson(item as Map<String, dynamic>))
          .toList(),
      fetchedAt:
          DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
