class ScheduleTask {
  const ScheduleTask({
    required this.id,
    required this.title,
    required this.note,
    required this.startAt,
    required this.endAt,
    required this.reminderMinutes,
    required this.createdAt,
    this.imagePath,
  });

  final String id;
  final String title;
  final String note;
  final DateTime startAt;
  final DateTime endAt;
  final int reminderMinutes;
  final DateTime createdAt;
  final String? imagePath;

  bool get hasReminder => reminderMinutes >= 0;

  String countdownLabel(DateTime now) {
    if (now.isBefore(startAt)) {
      return '距开始 ${_durationLabel(startAt.difference(now))}';
    }
    if (!now.isAfter(endAt)) {
      return '进行中 · 剩余 ${_durationLabel(endAt.difference(now))}';
    }
    return '已结束';
  }

  String _durationLabel(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) {
      return '$days天${hours > 0 ? '$hours小时' : ''}';
    }
    if (hours > 0) {
      return '$hours小时${minutes > 0 ? '$minutes分钟' : ''}';
    }
    return '${minutes < 1 ? 1 : minutes}分钟';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'startAt': startAt.toIso8601String(),
      'endAt': endAt.toIso8601String(),
      'reminderMinutes': reminderMinutes,
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
    };
  }

  factory ScheduleTask.fromJson(Map<String, dynamic> json) {
    return ScheduleTask(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      startAt:
          DateTime.tryParse(json['startAt'] as String? ?? '') ?? DateTime.now(),
      endAt:
          DateTime.tryParse(json['endAt'] as String? ?? '') ?? DateTime.now(),
      reminderMinutes: json['reminderMinutes'] as int? ?? -1,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      imagePath: json['imagePath'] as String?,
    );
  }
}
