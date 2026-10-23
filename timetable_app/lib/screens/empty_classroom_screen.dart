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
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  String? _lastQueryStatus;
  List<EmptyRoomCampus> _campuses = const [];
  List<EmptyRoomPeriod> _periods = const [];
  List<EmptyClassroom> _rooms = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded && !_loading) {
      final state = context.read<AppState>();
      _week = state.currentWeek;
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
      _lastQueryStatus = null;
    });
    try {
      final result = await context
          .read<AppState>()
          .repository
          .client
          .fetchEmptyClassrooms(
            week: _week,
            weekday: _weekday,
            term: context.read<AppState>().term,
            campus: _campus,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _loaded = true;
        _lastQueryStatus =
            '接口已返回：${result.periods.length} 个节次，'
            '${result.rooms.length} 间教室';
        _campuses = result.campuses;
        if (_campus.isNotEmpty &&
            !_campuses.any((campus) => campus.value == _campus)) {
          _campus = '';
        }
        _periods = result.periods;
        _rooms =
            result.rooms
                .where((room) => room.freePeriodCodes.isNotEmpty)
                .toList()
              ..sort((left, right) => left.name.compareTo(right.name));
      });
    } on SessionExpiredException {
      if (mounted) {
        setState(() => _error = '教务登录已失效，请重新登录');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
    _load();
  }

  void _changeCampus(String? value) {
    final next = value ?? '';
    if (next == _campus) {
      return;
    }
    setState(() => _campus = next);
    _load();
  }

  String _periodLabel(String code) {
    for (final period in _periods) {
      if (period.code == code) {
        return period.label;
      }
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('空教室查询')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '查询条件',
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _week <= 1 ? null : () => _changeWeek(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          '第 $_week 周',
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
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _weekday,
                    decoration: const InputDecoration(labelText: '星期'),
                    items:
                        const [
                              (1, '星期一'),
                              (2, '星期二'),
                              (3, '星期三'),
                              (4, '星期四'),
                              (5, '星期五'),
                              (6, '星期六'),
                              (7, '星期日'),
                            ]
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.$1,
                                child: Text(item.$2),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _changeWeekday(value);
                      }
                    },
                  ),
                  if (_campuses.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _campus,
                      decoration: const InputDecoration(labelText: '校区'),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('全部校区')),
                        ..._campuses.map(
                          (campus) => DropdownMenuItem(
                            value: campus.value,
                            child: Text(campus.label),
                          ),
                        ),
                      ],
                      onChanged: _changeCampus,
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _loading ? null : _load,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search_rounded),
                    label: Text(_loading ? '查询中' : '查询空教室'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _MessageCard(text: _error!, warning: true),
            ],
            if (_lastQueryStatus != null) ...[
              const SizedBox(height: 12),
              _MessageCard(text: _lastQueryStatus!),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  '空闲教室',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_rooms.length} 间',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!_loaded && _loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_rooms.isEmpty)
              _MessageCard(text: '当前条件下没有查询到空闲教室。')
            else
              ..._rooms.map(
                (room) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                            Icon(
                              Icons.meeting_room_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 21,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                room.name,
                                style: TextStyle(
                                  color: context.appText,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (room.capacity != null)
                              Text(
                                '${room.capacity} 人',
                                style: TextStyle(
                                  color: context.appMuted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: room.freePeriodCodes
                              .map(
                                (code) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _periodLabel(code),
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.text, this.warning = false});

  final String text;
  final bool warning;

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
      child: Text(
        text,
        style: TextStyle(color: context.appText, fontSize: 12, height: 1.5),
      ),
    );
  }
}
