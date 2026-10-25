import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/models/course.dart';
import 'package:timetable_app/services/schedule_parser.dart';
import 'package:timetable_app/services/schedule_utils.dart';

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

  test('课表节次和提醒开始时间使用学校实际时间', () {
    const course = Course(
      name: '大学英语',
      teacher: '李四',
      location: '南4',
      weekday: 3,
      startPeriod: 5,
      endPeriod: 6,
      weeks: [1],
      term: '2026-2027-1',
      timeText: '',
      displayTime: '',
      weekPeriodRaw: '',
    );

    expect(periodTimeRange(1), '08:30-09:15');
    expect(periodTimeRange(5), '12:45-13:30');
    expect(periodTimeRange(13), '20:40-21:25');
    expect(
      courseStartTime(DateTime(2026, 10, 21), course),
      DateTime(2026, 10, 21, 12, 45),
    );
  });

  test('自定义课程优先使用用户设置的显示时间', () {
    const course = Course(
      name: '高等数学',
      teacher: '张三',
      location: 'A101',
      weekday: 1,
      startPeriod: 2,
      endPeriod: 2,
      weeks: [1],
      term: '2026-2027-1',
      timeText: '',
      displayTime: '08:55-09:40',
      weekPeriodRaw: '',
      isCustom: true,
    );

    expect(
      courseStartTime(DateTime(2026, 10, 19), course),
      DateTime(2026, 10, 19, 8, 55),
    );
  });

  test('教务课程忽略滞后的导出显示时间并使用真实节次时间', () {
    const course = Course(
      name: '新闻学概论',
      teacher: '王迎新',
      location: '1A204',
      weekday: 1,
      startPeriod: 3,
      endPeriod: 4,
      weeks: [1],
      term: '2026-2027-1',
      timeText: '星期一 第3-4节 第1-16周',
      displayTime: '第三四节 10:25-12:00',
      weekPeriodRaw: '1-16(周)[03-04节]',
    );

    expect(
      courseStartTime(DateTime(2026, 10, 19), course),
      DateTime(2026, 10, 19, 10, 25),
    );
  });
}
