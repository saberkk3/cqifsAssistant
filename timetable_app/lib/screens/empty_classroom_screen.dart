import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_palette.dart';
import '../app_state.dart';
import '../app_theme.dart';
import '../models/empty_classroom.dart';
import '../services/jw_client.dart';
import 'login_screen.dart';

class EmptyClassroomScreen extends StatefulWidget {
  const EmptyClassroomScreen({super.key});

  @override
  State<EmptyClassroomScreen> createState() => _EmptyClassroomScreenState();
}

class _EmptyClassroomScreenState extends State<EmptyClassroomScreen> {
  int _week = 1;
  int _weekday = DateTime.now().weekday;
  String _campus = '';
  String _building = '';
  bool _loading = false;
  bool _loaded = false;
  bool _onlyFree = false;
  String? _error;
  String _term = '';
  List<EmptyRoomCampus> _campuses = const [];
  List<EmptyRoomBuilding> _buildings = const [];
  List<EmptyRoomPeriod> _periods = const [];
  List<EmptyClassroom> _rooms = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded && !_loading) {
      _week = context.read<AppState>().currentWeek;
      _load();
    }
  }

  Future<void> _load() async {
    if (_loading) {
      return;
    }
    final state = context.read<AppState>();
    if (state.needsLogin) {
      await Navigator.of(context)
          .push<void>(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (!mounted || context.read<AppState>().needsLogin) {
        return;
      }
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<AppState>()
          .repository
          .client
          .fetchClassroomTimetable(
            week: _week,
            term: context.read<AppState>().term,
            campus: _campus,
            building: _building,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = true;
        _term = result.term;
        _campuses = result.campuses;
        _buildings = result.buildings;
        _campus = result.campus;
        _building = result.building;
        _periods = result.periods;
        _rooms = result.rooms;
      });
    } on SessionExpiredException {
      if (mounted) {
        setState(() {
          _error = '教务登录状态已失效，请重新登录后查询。';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _friendlyError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    if (text.contains('SocketException') || text.contains('Connection')) {
      return '网络连接失败，请检查网络后重试。';
    }
    return text;
  }

  List<EmptyClassroom> get _visibleRooms {
    final result = _rooms
        .where(
          (room) =>
              !_onlyFree || room.freePeriodCodes(_weekday, _periods).isNotEmpty,
        )
        .toList();
    result.sort((left, right) {
      final leftFree = left.freePeriodCodes(_weekday, _periods).length;
      final rightFree = right.freePeriodCodes(_weekday, _periods).length;
      final freeCompare = rightFree.compareTo(leftFree);
      if (freeCompare != 0) {
        return freeCompare;
      }
      return left.name.compareTo(right.name);
    });
    return result;
  }

  void _changeWeek(int delta) {
    final next = (_week + delta).clamp(1, 30);
    if (next == _week) {
      return;
    }
    setState(() => _week = next);
    _load();
  }

  void _changeWeekday(int value) {
    if (value == _weekday) {
      return;
    }
    setState(() => _weekday = value);
  }

  void _changeCampus(String? value) {
    final next = value ?? '';
    if (next == _campus) {
      return;
    }
    setState(() {
      _campus = next;
      _building = '';
      _buildings = const [];
    });
    _load();
  }

  void _changeBuilding(String? value) {
    final next = value ?? '';
    if (next == _building) {
      return;
    }
    setState(() => _building = next);
    _load();
  }

  void _openRoom(EmptyClassroom room) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _RoomScheduleSheet(
          room: room,
          week: _week,
          term: _term,
          periods: _periods,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleRooms = _visibleRooms;
    final freeCount = _rooms
        .where((room) => room.freePeriodCodes(_weekday, _periods).isNotEmpty)
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('教室课表'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            _buildQueryCard(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _MessageCard(
                text: _error!,
                warning: true,
                actionLabel: '重新登录',
                onAction: () async {
                  final state = context.read<AppState>();
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  if (mounted && !state.needsLogin) {
                    _load();
                  }
                },
              ),
            ],
            const SizedBox(height: 18),
            if (_loaded)
              Row(
                children: [
                  Text(
                    _weekdayLabel(_weekday),
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${visibleRooms.length} 间教室 · $freeCount 间有闲时',
                    style: TextStyle(color: context.appMuted, fontSize: 11),
                  ),
                ],
              ),
            if (_loaded) const SizedBox(height: 10),
            if (_loading && !_loaded)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 46),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_loaded && visibleRooms.isEmpty)
              _MessageCard(
                text: _onlyFree
                    ? '当前筛选下没有空闲教室，可关闭“仅看当前空闲”后查看全部教室。'
                    : '未查询到教室课表，请切换教学楼或教学周后重试。',
              )
            else
              ...visibleRooms.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RoomCard(
                    room: room,
                    weekday: _weekday,
                    periods: _periods,
                    onTap: () => _openRoom(room),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.meeting_room_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                '查询条件',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _week <= 1 ? null : () => _changeWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '第 $_week 教学周',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _week >= 30 ? null : () => _changeWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final day = index + 1;
                final selected = day == _weekday;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_shortDayLabel(day)),
                    selected: selected,
                    onSelected: (_) => _changeWeekday(day),
                  ),
                );
              }),
            ),
          ),
          if (_campuses.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _campuses.any((campus) => campus.value == _campus)
                  ? _campus
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '校区'),
              items: _campuses
                  .map(
                    (campus) => DropdownMenuItem(
                      value: campus.value,
                      child: Text(
                        campus.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _loading ? null : _changeCampus,
            ),
          ],
          if (_buildings.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _building.isEmpty ? '' : _building,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '教学楼'),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部教学楼')),
                ..._buildings.map(
                  (building) => DropdownMenuItem(
                    value: building.value,
                    child: Text(
                      building.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _loading ? null : _changeBuilding,
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '仅看当前空闲',
              style: TextStyle(
                color: context.appText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '按${_weekdayLabel(_weekday)}的课表筛选',
              style: TextStyle(color: context.appMuted, fontSize: 11),
            ),
            value: _onlyFree,
            onChanged: (value) => setState(() => _onlyFree = value),
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search_rounded),
            label: Text(_loading ? '查询中' : '查询教室课表'),
          ),
        ],
      ),
    );
  }

  String _shortDayLabel(int day) {
    return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day - 1];
  }

  String _weekdayLabel(int day) {
    return const ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][day - 1];
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.weekday,
    required this.periods,
    required this.onTap,
  });

  final EmptyClassroom room;
  final int weekday;
  final List<EmptyRoomPeriod> periods;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final occupied = room.occupiedPeriodCodes(weekday);
    final free = room.freePeriodCodes(weekday, periods);
    final allFree = periods.isNotEmpty && free.length == periods.length;
    final full = periods.isNotEmpty && free.isEmpty;
    final accent = full
        ? AppColors.warning
        : allFree
        ? AppColors.success
        : Theme.of(context).colorScheme.primary;
    final status = full
        ? '当天满课'
        : allFree
        ? '全天空闲'
        : '空闲 ${free.length}/${periods.length}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.appBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.door_front_door_outlined,
                      color: accent,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.name,
                          style: TextStyle(
                            color: context.appText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (room.building.isNotEmpty ||
                            room.capacity != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (room.building.isNotEmpty) room.building,
                              if (room.capacity != null) '${room.capacity} 人',
                            ].join(' · '),
                            style: TextStyle(
                              color: context.appMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (free.isEmpty)
                Text(
                  occupied.isEmpty ? '暂时没有课表数据' : '本日各大节均有课程',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                )
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: free
                      .map(
                        (code) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            code,
                            style: TextStyle(
                              color: accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 9),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '查看本周课表',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomScheduleSheet extends StatelessWidget {
  const _RoomScheduleSheet({
    required this.room,
    required this.week,
    required this.term,
    required this.periods,
  });

  final EmptyClassroom room;
  final int week;
  final String term;
  final List<EmptyRoomPeriod> periods;

  static const _days = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            room.name,
            style: TextStyle(
              color: context.appText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '第 $week 周 · ${term.isEmpty ? '当前学期' : term}'
            '${room.building.isEmpty ? '' : ' · ${room.building}'}',
            style: TextStyle(color: context.appMuted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          _buildTimetable(context),
          const SizedBox(height: 20),
          Text(
            '课程详情',
            style: TextStyle(
              color: context.appText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(7, (index) {
            final day = index + 1;
            final entries = <(EmptyRoomPeriod, List<String>)>[];
            for (final period in periods) {
              final contents = room.contentsFor(day, period.code);
              if (contents.isNotEmpty) {
                entries.add((period, contents));
              }
            }
            if (entries.isEmpty) {
              return const SizedBox.shrink();
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '星期${_days[index]}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              entry.$1.shortLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              entry.$2.join('\n\n'),
                              style: TextStyle(
                                color: context.appText,
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimetable(BuildContext context) {
    const firstColumnWidth = 60.0;
    const dayWidth = 86.0;
    final primary = Theme.of(context).colorScheme.primary;
    final cellStyle = TextStyle(
      color: context.appText,
      fontSize: 8,
      height: 1.25,
    );
    Widget dayCell(int day, EmptyRoomPeriod period) {
      final contents = room.contentsFor(day, period.code);
      if (contents.isEmpty) {
        return Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(5),
          color: AppColors.success.withValues(alpha: 0.08),
          child: Text(
            '空',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }
      final firstLine = contents.first.split('\n').first.trim();
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(5),
        color: primary.withValues(alpha: 0.1),
        child: Text(
          firstLine.isEmpty ? '有课' : firstLine,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: cellStyle,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: firstColumnWidth + dayWidth * 7,
        child: Table(
          border: TableBorder.all(color: context.appBorder, width: 0.7),
          columnWidths: {
            0: const FixedColumnWidth(firstColumnWidth),
            for (var index = 1; index <= 7; index++)
              index: const FixedColumnWidth(dayWidth),
          },
          children: [
            TableRow(
              children: [
                _HeaderCell(text: '节次'),
                ..._days.map((day) => _HeaderCell(text: '周$day')),
              ],
            ),
            ...periods.map(
              (period) => TableRow(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 7,
                    ),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          period.shortLabel,
                          style: TextStyle(
                            color: primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (period.startTime != null)
                          Text(
                            period.startTime!,
                            style: TextStyle(
                              color: context.appMuted,
                              fontSize: 7,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...List.generate(7, (index) => dayCell(index + 1, period)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.text,
    this.warning = false,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final bool warning;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? AppColors.warning
        : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.appText,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
