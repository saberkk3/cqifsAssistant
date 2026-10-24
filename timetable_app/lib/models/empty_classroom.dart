class EmptyRoomCampus {
  const EmptyRoomCampus({required this.value, required this.label});

  final String value;
  final String label;
}

class EmptyRoomBuilding {
  const EmptyRoomBuilding({required this.value, required this.label});

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

  String get shortLabel => code;

  String get label {
    final matches = RegExp(r'\d{2}').allMatches(code);
    final periods = matches
        .map((match) => int.tryParse(match.group(0) ?? ''))
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
    required this.building,
    required this.capacity,
    required this.timetable,
  });

  final String name;
  final String building;
  final int? capacity;
  final Map<int, Map<String, List<String>>> timetable;

  List<String> contentsFor(int weekday, String periodCode) {
    return timetable[weekday]?[periodCode] ?? const [];
  }

  List<String> occupiedPeriodCodes(int weekday) {
    final day = timetable[weekday];
    if (day == null) {
      return const [];
    }
    return day.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => entry.key)
        .toList()
      ..sort();
  }

  List<String> freePeriodCodes(int weekday, List<EmptyRoomPeriod> periods) {
    final occupied = occupiedPeriodCodes(weekday).toSet();
    return periods
        .where((period) => !occupied.contains(period.code))
        .map((period) => period.code)
        .toList();
  }

  bool isFreeAllDay(List<EmptyRoomPeriod> periods, int weekday) {
    return freePeriodCodes(weekday, periods).length == periods.length;
  }
}

class EmptyClassroomResult {
  const EmptyClassroomResult({
    required this.term,
    required this.campuses,
    required this.buildings,
    required this.campus,
    required this.building,
    required this.periods,
    required this.rooms,
  });

  final String term;
  final List<EmptyRoomCampus> campuses;
  final List<EmptyRoomBuilding> buildings;
  final String campus;
  final String building;
  final List<EmptyRoomPeriod> periods;
  final List<EmptyClassroom> rooms;
}
