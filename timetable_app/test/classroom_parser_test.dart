import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/services/classroom_parser.dart';

void main() {
  test('解析教室课表页面的学期、校区和教学楼', () {
    const html = '''
      <input name="xnxqh" value="2026-2027-1">
      <input name="kbjcmsid" value="TIME-MODE">
      <select name="xqid">
        <option value="01" selected="selected">渝北校区</option>
        <option value="02">綦江校区</option>
      </select>
      <select name="jzwid">
        <option value="">全部教学楼</option>
        <option value="10" selected="selected">第一教学楼</option>
      </select>
    ''';

    final page = ClassroomParser().parseQueryPage(html);

    expect(page.term, '2026-2027-1');
    expect(page.timeMode, 'TIME-MODE');
    expect(page.campus, '01');
    expect(page.building, '10');
    expect(page.campuses, hasLength(2));
    expect(page.buildings.single.label, '第一教学楼');
  });

  test('解析教学楼 AJAX 返回数据', () {
    const json = '''
      [
        {"dm":"10","dmmc":"第一教学楼"},
        {"dm":"11","dmmc":"实训楼"}
      ]
    ''';

    final buildings = ClassroomParser().parseBuildingsJson(json);

    expect(buildings, hasLength(2));
    expect(buildings.first.value, '10');
    expect(buildings.last.label, '实训楼');
  });

  test('保留“全部教学楼”的空值默认选项', () {
    const html = '''
      <select name="xqid">
        <option value="01" selected="selected">渝北校区</option>
      </select>
      <select name="jzwid">
        <option value="" selected="selected">全部教学楼</option>
        <option value="10">第一教学楼</option>
      </select>
    ''';

    final page = ClassroomParser().parseQueryPage(html);

    expect(page.campus, '01');
    expect(page.building, isEmpty);
  });

  test('解析 kbtable 中的教室、容量和七天课程网格', () {
    const periodCodes = ['0102', '0304', '0506', '0708', '0910', '1112', '13'];
    final secondHeader = [
      '<td>教室\\节次</td>',
      for (var day = 0; day < 7; day++)
        ...periodCodes.map((code) => '<td>$code</td>'),
    ].join();
    final cells = List.generate(49, (index) {
      if (index == 0) {
        return '<td><div class="kbcontent1">高等数学<br>张三<br>1-16周<br>A101</div></td>';
      }
      if (index == 7) {
        return '<td><div class="kbcontent1">大学英语<br>李四<br>1-8周</div></td>';
      }
      if (index == 48) {
        return '<td><div class="kbcontent1">晚自习<br>王老师</div></td>';
      }
      return '<td><div class="kbcontent1">&nbsp;</div></td>';
    }).join();
    final html =
        '''
      <table id="kbtable">
        <thead>
          <tr><td>教室</td><td>星期一</td></tr>
          <tr>$secondHeader</tr>
        </thead>
        <tr><td>A101（60/60）</td>$cells</tr>
      </table>
    ''';

    final data = ClassroomParser().parseTable(html);
    final room = data.rooms.single;

    expect(data.periods, hasLength(7));
    expect(data.periods.first.startTime, '08:00');
    expect(data.periods.first.endTime, '09:40');
    expect(data.periods.last.code, '13');
    expect(data.periods.last.startTime, '22:40');
    expect(room.name, 'A101');
    expect(room.capacity, 60);
    expect(room.contentsFor(1, '0102').first, contains('高等数学'));
    expect(room.contentsFor(2, '0102').first, contains('大学英语'));
    expect(room.contentsFor(7, '13').first, contains('晚自习'));
    expect(room.freePeriodCodes(1, data.periods), isNot(contains('0102')));
    expect(room.freePeriodCodes(1, data.periods), contains('0304'));
  });
}
