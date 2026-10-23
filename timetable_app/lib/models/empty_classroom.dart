class EmptyRoomCampus {
  const EmptyRoomCampus({required this.value, required this.label});

  final String value;
  final String label;
}

class EmptyRoomPeriod {
  const EmptyRoomPeriod({
    required this.code,
    required this.startTime,
    required this.endTime,
  });

  final String code;
  final String? startTime;
  final String? endTime;

  String get label {
    final numbers = RegExp(r'\d{2}').allMatches(code).map((m) => m.group(0));
    final periods = numbers
        .map((value) => int.tryParse(value ?? ''))
        .whereType<int>()
        .toList();
    final periodLabel = periods.isEmpty
        ? code
        : periods.length == 1
        ? '第${periods.first}节'
        : '第${periods.first}-${periods.last}节';
    if (startTime == null || endTime == null) {
      return periodLabel;
    }
    return '$periodLabel $startTime-$endTime';
  }
}

class EmptyClassroom {
  const EmptyClassroom({
    required this.name,
    required this.capacity,
    required this.freePeriodCodes,
  });

  final String name;
  final int? capacity;
  final List<String> freePeriodCodes;
}

class EmptyClassroomResult {
  const EmptyClassroomResult({
    required this.term,
    required this.campuses,
    required this.periods,
    required this.rooms,
  });

  final String term;
  final List<EmptyRoomCampus> campuses;
  final List<EmptyRoomPeriod> periods;
  final List<EmptyClassroom> rooms;
}
