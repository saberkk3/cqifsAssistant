import 'package:flutter_test/flutter_test.dart';
import 'package:timetable_app/models/inspiration_entry.dart';

void main() {
  test('每日灵感 JSON 往返保持内容与时间', () {
    final created = DateTime(2026, 10, 24, 9, 30);
    final updated = created.add(const Duration(minutes: 10));
    final entry = InspirationEntry(
      id: 'idea-1',
      content: '做一个自动整理日程的小工具',
      createdAt: created,
      updatedAt: updated,
    );

    final restored = InspirationEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.content, entry.content);
    expect(restored.createdAt, created);
    expect(restored.updatedAt, updated);
  });

  test('编辑灵感不会改变创建时间', () {
    final created = DateTime(2026, 10, 24, 9, 30);
    final entry = InspirationEntry(
      id: 'idea-1',
      content: '初始想法',
      createdAt: created,
      updatedAt: created,
    );
    final changedAt = created.add(const Duration(hours: 1));

    final edited = entry.copyWith(content: '修改后的想法', updatedAt: changedAt);

    expect(edited.content, '修改后的想法');
    expect(edited.createdAt, created);
    expect(edited.updatedAt, changedAt);
  });
}
