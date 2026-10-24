import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/empty_classroom.dart';
import 'schedule_utils.dart';

class ClassroomQueryPage {
  const ClassroomQueryPage({
    required this.term,
    required this.timeMode,
    required this.campus,
    required this.building,
    required this.campuses,
    required this.buildings,
  });

  final String term;
  final String timeMode;
  final String campus;
  final String building;
  final List<EmptyRoomCampus> campuses;
  final List<EmptyRoomBuilding> buildings;
}

class ClassroomTableData {
  const ClassroomTableData({required this.periods, required this.rooms});

  final List<EmptyRoomPeriod> periods;
  final List<EmptyClassroom> rooms;
}

class ClassroomParser {
  static const _fallbackPeriodCodes = [
    '0102',
    '0304',
    '0506',
    '0708',
    '0910',
    '1112',
    '13',
  ];

  ClassroomQueryPage parseQueryPage(String html) {
    final document = html_parser.parse(html);
    final campuses = _options(document, const ['xqid', 'xqbh']);
    final buildings = _options(document, const ['jzwid', 'jxlvalue'])
        .map((item) => EmptyRoomBuilding(value: item.value, label: item.label))
        .toList();
    final campus =
        _selectedOrInputValue(document, const ['xqid', 'xqbh']) ??
        (campuses.isEmpty ? '' : campuses.first.value);
    final building =
        _selectedOrInputValue(document, const [
          'jzwid',
          'jxlvalue',
        ], allowEmptySelection: true) ??
        '';
    return ClassroomQueryPage(
      term: _selectedOrInputValue(document, const ['xnxqh']) ?? '',
      timeMode: _selectedOrInputValue(document, const ['kbjcmsid']) ?? '',
      campus: campus,
      building: building,
      campuses: campuses,
      buildings: buildings,
    );
  }

  List<EmptyRoomBuilding> parseBuildingsJson(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const [];
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start < 0 || end <= start) {
        return const [];
      }
      try {
        decoded = jsonDecode(text.substring(start, end + 1));
      } on FormatException {
        return const [];
      }
    }

    final items = _findBuildingList(decoded);
    final buildings = <EmptyRoomBuilding>[];
    final values = <String>{};
    for (final item in items) {
      if (item is! Map) {
        continue;
      }
      final value = _mapValue(item, const ['dm', 'id', 'jzwid', 'value']) ?? '';
      final label =
          _mapValue(item, const ['dmmc', 'name', 'jzwmc', 'label']) ?? value;
      if (value.isEmpty || !values.add(value)) {
        continue;
      }
      buildings.add(
        EmptyRoomBuilding(value: value, label: label.isEmpty ? value : label),
      );
    }
    return buildings;
  }

  ClassroomTableData parseTable(String html) {
    final document = html_parser.parse(html);
    final table =
        document.querySelector('#kbtable') ??
        document.querySelector('table.kb_table');
    if (table == null) {
      throw const FormatException('教室课表结果缺少 kbtable 表格');
    }

    final periods = _parsePeriods(table);
    final periodCodes = periods.map((period) => period.code).toList();
    final rooms = <EmptyClassroom>[];
    for (final row in table.querySelectorAll('tr')) {
      final cells = row.children
          .where(
            (element) => element.localName == 'td' || element.localName == 'th',
          )
          .toList();
      if (cells.length < 2) {
        continue;
      }

      final roomLabel = _textWithBreaks(cells.first)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (roomLabel.isEmpty ||
          roomLabel == '教室' ||
          roomLabel.contains('节次') ||
          roomLabel.contains('星期')) {
        continue;
      }

      final roomInfo = _parseRoomLabel(roomLabel);
      final timetable = <int, Map<String, List<String>>>{};
      for (var dayIndex = 0; dayIndex < 7; dayIndex++) {
        final day = <String, List<String>>{};
        for (
          var periodIndex = 0;
          periodIndex < periodCodes.length;
          periodIndex++
        ) {
          final cellIndex = 1 + dayIndex * periodCodes.length + periodIndex;
          if (cellIndex >= cells.length) {
            continue;
          }
          final contents = _cellContents(cells[cellIndex]);
          if (contents.isNotEmpty) {
            day[periodCodes[periodIndex]] = contents;
          }
        }
        if (day.isNotEmpty) {
          timetable[dayIndex + 1] = day;
        }
      }

      rooms.add(
        EmptyClassroom(
          name: roomInfo.$1,
          building: '',
          capacity: roomInfo.$2,
          timetable: timetable,
        ),
      );
    }

    return ClassroomTableData(periods: periods, rooms: rooms);
  }

  String? _selectedOrInputValue(
    dom.Document document,
    List<String> names, {
    bool allowEmptySelection = false,
  }) {
    for (final name in names) {
      final select = document.querySelector('select[name="$name"]');
      if (select != null) {
        final options = select.querySelectorAll('option');
        final selected = select.querySelector('option[selected]');
        final selectedValue = selected == null
            ? null
            : (_attribute(selected, 'value') ?? _cleanText(selected.text));
        if (selectedValue != null &&
            (allowEmptySelection || selectedValue.isNotEmpty)) {
          return selectedValue;
        }
        for (final option in options) {
          final value = _attribute(option, 'value') ?? '';
          if (value.isNotEmpty) {
            return value;
          }
        }
      }
      final input = document.querySelector('input[name="$name"]');
      if (input != null) {
        final value = _attribute(input, 'value') ?? '';
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
    return null;
  }

  List<EmptyRoomCampus> _options(dom.Document document, List<String> names) {
    for (final name in names) {
      final select = document.querySelector('select[name="$name"]');
      if (select == null) {
        continue;
      }
      final result = <EmptyRoomCampus>[];
      final values = <String>{};
      for (final option in select.querySelectorAll('option')) {
        final value = _attribute(option, 'value') ?? '';
        final label = _cleanText(option.text);
        if (value.isEmpty || !values.add(value)) {
          continue;
        }
        result.add(
          EmptyRoomCampus(value: value, label: label.isEmpty ? value : label),
        );
      }
      if (result.isNotEmpty) {
        return result;
      }
    }
    return const [];
  }

  List<EmptyRoomPeriod> _parsePeriods(dom.Element table) {
    final codes = <String>[];
    final seen = <String>{};
    final headerRows =
        table.querySelector('thead')?.querySelectorAll('tr').toList() ??
        table.querySelectorAll('tr').take(2).toList();
    final periodPattern = RegExp(r'^(?:\d{2}|\d{3,4})$');
    for (final row in headerRows) {
      for (final cell in row.children) {
        if (cell.localName != 'td' && cell.localName != 'th') {
          continue;
        }
        final code = _cleanText(cell.text);
        if (periodPattern.hasMatch(code) && seen.add(code)) {
          codes.add(code);
        }
      }
    }
    return _periodsForCodes(codes.isEmpty ? _fallbackPeriodCodes : codes);
  }

  List<EmptyRoomPeriod> _periodsForCodes(List<String> codes) {
    return codes.map((code) {
      final numbers = RegExp(r'\d{2}')
          .allMatches(code)
          .map((match) => int.tryParse(match.group(0) ?? ''))
          .whereType<int>()
          .toList();
      if (numbers.isEmpty) {
        return EmptyRoomPeriod(code: code, startTime: null, endTime: null);
      }
      final startIndex = (numbers.first - 1).clamp(
        0,
        periodSchedule.length - 1,
      );
      final endIndex = (numbers.last - 1).clamp(0, periodSchedule.length - 1);
      final start = periodSchedule[startIndex];
      final end = periodSchedule[endIndex];
      return EmptyRoomPeriod(
        code: code,
        startTime: _clock(start.$1, start.$2),
        endTime: _clock(end.$3, end.$4),
      );
    }).toList();
  }

  (String, int?) _parseRoomLabel(String label) {
    final match = RegExp(
      r'^(.*?)\s*[（(]\s*(\d{1,5})\s*(?:人)?(?:\s*/\s*\d{1,5}\s*(?:人)?)?\s*[)）]',
    ).firstMatch(label);
    if (match == null) {
      return (label, null);
    }
    final name = (match.group(1) ?? '').trim();
    return (name.isEmpty ? label : name, int.tryParse(match.group(2) ?? ''));
  }

  List<String> _cellContents(dom.Element cell) {
    final blocks = cell.querySelectorAll('.kbcontent1');
    final result = <String>[];
    final seen = <String>{};

    if (blocks.isNotEmpty) {
      for (final block in blocks) {
        final text = _normalizeCellText(_textWithBreaks(block));
        if (text.isNotEmpty && seen.add(text)) {
          result.add(text);
        }
      }
      return result;
    }

    final fallback = _normalizeCellText(_textWithBreaks(cell));
    if (fallback.isNotEmpty) {
      result.add(fallback);
    }
    return result;
  }

  String _normalizeCellText(String value) {
    final lines = value
        .replaceAll('\u00a0', ' ')
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty && line != '&nbsp;')
        .toList();
    return lines.join('\n').trim();
  }

  String _textWithBreaks(dom.Node node) {
    final buffer = StringBuffer();
    void visit(dom.Node current) {
      if (current is dom.Text) {
        buffer.write(current.data);
        return;
      }
      if (current is dom.Element && current.localName == 'br') {
        buffer.write('\n');
        return;
      }
      for (final child in current.nodes) {
        visit(child);
      }
    }

    visit(node);
    return buffer.toString();
  }

  String _cleanText(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String? _attribute(dom.Element element, String name) {
    for (final entry in element.attributes.entries) {
      if (entry.key.toString().toLowerCase() == name.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  String _clock(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  List<dynamic> _findBuildingList(dynamic value) {
    if (value is List) {
      if (value.any((item) => item is Map)) {
        return value;
      }
      for (final item in value) {
        final nested = _findBuildingList(item);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
      return const [];
    }
    if (value is Map) {
      for (final item in value.values) {
        final nested = _findBuildingList(item);
        if (nested.isNotEmpty) {
          return nested;
        }
      }
    }
    return const [];
  }

  String? _mapValue(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return null;
  }
}
