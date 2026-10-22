import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../models/course.dart';

class ParsedSchedule {
  const ParsedSchedule({
    required this.term,
    required this.terms,
    required this.courses,
  });

  final String term;
  final List<String> terms;
  final List<Course> courses;
}

class ScheduleParser {
  static const _weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

  ParsedSchedule parse(String html) {
    final document = html_parser.parse(html);
    final terms = document
        .querySelectorAll('#xnxq01id option')
        .map((option) => (option.attributes['value'] ?? '').trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final selectedOption =
        document.querySelector('#xnxq01id option[selected]') ??
        document.querySelector('#xnxq01id option');
    final term = (selectedOption?.attributes['value'] ?? '').trim();

    final table = document.querySelector('#kbtable');
    if (table == null) {
      throw const FormatException('未找到课表表格');
    }

    final rows = table.querySelectorAll('tr');
    if (rows.isEmpty) {
      throw const FormatException('课表表格为空');
    }

    final headerCells = _directCells(rows.first);
    final dayColumns = <int, String>{};
    var headerColumn = 0;
    for (final cell in headerCells) {
      final text = _clean(cell.text);
      final colspan = _span(cell, 'colspan');
      for (var offset = 0; offset < colspan; offset++) {
        if (_weekdays.contains(text)) {
          dayColumns[headerColumn + offset] = text;
        }
      }
      headerColumn += colspan;
    }

    if (dayColumns.isEmpty) {
      throw const FormatException('未找到星期一至星期日表头');
    }

    final records = <Course>[];
    final seen = <String>{};

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final cells = _directCells(rows[rowIndex]);
      if (cells.length < 2) {
        continue;
      }

      final rowLabel = _clean(cells.first.text);
      var column = 0;
      for (final cell in cells) {
        final colspan = _span(cell, 'colspan');
        final weekday = dayColumns[column];
        if (weekday == null) {
          column += colspan;
          continue;
        }

        for (final block in cell.querySelectorAll('div.kbcontent')) {
          final rawText = _clean(block.text);
          if (rawText.isEmpty || rawText == '\u00a0') {
            continue;
          }

          var teacher = '未标注';
          var location = '未标注';
          var weekPeriod = '';
          final metaValues = <String>{};
          for (final font in block.querySelectorAll('font')) {
            final title = (font.attributes['title'] ?? '').trim();
            final value = _clean(font.text);
            if (value.isEmpty) {
              continue;
            }
            metaValues.add(value);
            if (title.contains('老师') || title.contains('教师')) {
              teacher = value;
            } else if (title.contains('周次')) {
              weekPeriod = value;
            } else if (title.contains('教室') || title.contains('地点')) {
              location = value;
            }
          }

          var courseName = _firstDirectText(block);
          if (courseName.isEmpty) {
            courseName = block.text
                .split(RegExp(r'[\r\n]+'))
                .map(_clean)
                .firstWhere(
                  (item) => item.isNotEmpty && !metaValues.contains(item),
                  orElse: () => '',
                );
          }
          courseName = courseName.replaceFirst(RegExp(r'^[＊*]\s*'), '').trim();
          if (courseName.isEmpty) {
            continue;
          }

          final periods = _parsePeriods(weekPeriod);
          final fallbackStart = rowIndex * 2 - 1;
          final startPeriod = periods.isEmpty ? fallbackStart : periods.first;
          final endPeriod = periods.isEmpty ? fallbackStart + 1 : periods.last;
          final weeks = _parseWeeks(weekPeriod);
          final termValue = term;

          final timeText = _buildTimeText(
            weekday: weekday,
            startPeriod: startPeriod,
            endPeriod: endPeriod,
            weeks: weeks,
          );
          final key = [
            courseName,
            weekday,
            weekPeriod,
            location,
            teacher,
          ].join('|');
          if (!seen.add(key)) {
            continue;
          }

          records.add(
            Course(
              name: courseName,
              teacher: teacher,
              location: location,
              weekday: _weekdays.indexOf(weekday) + 1,
              startPeriod: startPeriod,
              endPeriod: endPeriod,
              weeks: weeks,
              term: termValue,
              timeText: timeText,
              displayTime: rowLabel,
              weekPeriodRaw: weekPeriod,
            ),
          );
        }
        column += colspan;
      }
    }

    records.sort((left, right) {
      final dayCompare = left.weekday.compareTo(right.weekday);
      if (dayCompare != 0) {
        return dayCompare;
      }
      return left.startPeriod.compareTo(right.startPeriod);
    });

    return ParsedSchedule(term: term, terms: terms, courses: records);
  }

  List<dom.Element> _directCells(dom.Element row) {
    return row.children
        .where(
          (element) => element.localName == 'th' || element.localName == 'td',
        )
        .toList();
  }

  int _span(dom.Element element, String name) {
    return int.tryParse(element.attributes[name] ?? '') ?? 1;
  }

  String _firstDirectText(dom.Element block) {
    for (final node in block.nodes) {
      if (node is dom.Text) {
        final text = _clean(node.text);
        if (text.isNotEmpty) {
          return text;
        }
      } else if (node is dom.Element &&
          node.localName != 'font' &&
          node.localName != 'br') {
        final text = _clean(node.text);
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return '';
  }

  List<int> _parsePeriods(String weekPeriod) {
    final match = RegExp(r'\[([0-9,\-]+)节\]').firstMatch(weekPeriod);
    if (match == null) {
      return const [];
    }
    final values = RegExp(r'\d+')
        .allMatches(match.group(1) ?? '')
        .map((item) => int.parse(item.group(0)!))
        .toList();
    if (values.isEmpty) {
      return const [];
    }
    values.sort();
    return values;
  }

  List<int> _parseWeeks(String weekPeriod) {
    var source = weekPeriod.split('周').first;
    source = source
        .replaceAll('至', '-')
        .replaceAll('~', '-')
        .replaceAll('，', ',')
        .replaceAll('、', ',')
        .replaceAll(RegExp(r'[^0-9,\-]'), '');
    final weeks = <int>{};
    for (final part in source.split(',')) {
      if (part.isEmpty) {
        continue;
      }
      final range = part.split('-').where((item) => item.isNotEmpty).toList();
      if (range.length == 1) {
        final week = int.tryParse(range.first);
        if (week != null) {
          weeks.add(week);
        }
      } else if (range.length >= 2) {
        final start = int.tryParse(range.first);
        final end = int.tryParse(range.last);
        if (start != null && end != null && end >= start) {
          for (var week = start; week <= end; week++) {
            weeks.add(week);
          }
        }
      }
    }
    if (weekPeriod.contains('单')) {
      weeks.removeWhere((week) => week.isEven);
    }
    if (weekPeriod.contains('双')) {
      weeks.removeWhere((week) => week.isOdd);
    }
    final result = weeks.toList()..sort();
    return result;
  }

  String _buildTimeText({
    required String weekday,
    required int startPeriod,
    required int endPeriod,
    required List<int> weeks,
  }) {
    final period = startPeriod == endPeriod
        ? '第$startPeriod节'
        : '第$startPeriod-$endPeriod节';
    final weekText = weeks.isEmpty
        ? ''
        : weeks.length == 1
        ? '第${weeks.first}周'
        : '第${weeks.first}-${weeks.last}周';
    return [
      weekday,
      period,
      weekText,
    ].where((item) => item.isNotEmpty).join(' ');
  }

  String _clean(String value) {
    return value
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
