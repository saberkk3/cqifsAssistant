import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/services/schedule_parser.dart';

void main() {
  test('解析课程名称、老师、地点、星期和周次', () {
    const html = '''
      <select id="xnxq01id">
        <option value="2026-2027-1" selected="selected">2026-2027-1</option>
      </select>
      <table id="kbtable">
        <tr>
          <th></th>
          <th>星期一</th>
          <th>星期二</th>
          <th>星期三</th>
          <th>星期四</th>
          <th>星期五</th>
          <th>星期六</th>
          <th>星期日</th>
        </tr>
        <tr>
          <th>第一二节 08:30-10:05</th>
          <td>
            <div class="kbcontent">
              高等数学
              <font title="老师">张三</font>
              <font title="周次(节次)">1-16(周)[01-02节]</font>
              <font title="教室">A101</font>
            </div>
          </td>
          <td></td>
          <td></td>
          <td></td>
          <td></td>
          <td></td>
          <td></td>
        </tr>
      </table>
    ''';

    final parsed = ScheduleParser().parse(html);
    expect(parsed.term, '2026-2027-1');
    expect(parsed.courses, hasLength(1));
    expect(parsed.courses.first.name, '高等数学');
    expect(parsed.courses.first.teacher, '张三');
    expect(parsed.courses.first.location, 'A101');
    expect(parsed.courses.first.weekday, 1);
    expect(parsed.courses.first.startPeriod, 1);
    expect(parsed.courses.first.endPeriod, 2);
    expect(parsed.courses.first.weeks, List.generate(16, (index) => index + 1));
  });
}
