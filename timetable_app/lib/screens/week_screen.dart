import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../app_palette.dart';
import '../models/course.dart';
import '../services/schedule_utils.dart';
import '../widgets/course_card.dart';
import '../widgets/empty_state.dart';
import 'course_editor_screen.dart';

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  int _week = 1;
  int _day = DateTime.now().weekday;
  bool _overview = true;
  String? _lastTerm;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    if (_lastTerm != state.term) {
      _lastTerm = state.term;
      _week = state.currentWeek;
      _day = DateTime.now().weekday;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final primary = Theme.of(context).colorScheme.primary;
    final primarySoft = Theme.of(context).colorScheme.primaryContainer;
    final backgroundImagePath = state.settings.timetableBackgroundImagePath;
    final hasBackgroundImage = _hasBackgroundImage(state);
    final totalWeeks = _totalWeeks(state);
    final weekStart = termStartDate(
      state.term,
      firstWeekStart: state.settings.firstWeekStarts[state.term],
    )?.add(Duration(days: (_week - 1) * 7));
    final weekEnd = weekStart?.add(const Duration(days: 6));
    final dayCourses = coursesForDay(state.courses, weekday: _day, week: _week);
    final weekCourses =
        state.courses.where((course) => course.occursInWeek(_week)).toList()
          ..sort((left, right) {
            final dayCompare = left.weekday.compareTo(right.weekday);
            if (dayCompare != 0) {
              return dayCompare;
            }
            return left.startPeriod.compareTo(right.startPeriod);
          });

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: state.timetableBackground,
      appBar: AppBar(
        toolbarHeight: 52,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: context.appText,
        titleSpacing: 14,
        title: state.terms.length > 1
            ? DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: state.terms.contains(state.term)
                      ? state.term
                      : state.terms.first,
                  isDense: true,
                  dropdownColor: context.appCard,
                  borderRadius: BorderRadius.circular(14),
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  items: state.terms
                      .map(
                        (term) =>
                            DropdownMenuItem(value: term, child: Text(term)),
                      )
                      .toList(),
                  onChanged: (term) async {
                    if (term == null) {
                      return;
                    }
                    await state.selectTerm(term);
                    if (mounted) {
                      setState(() {
                        _week = state.currentWeek;
                        _day = DateTime.now().weekday;
                      });
                    }
                  },
                ),
              )
            : Text(
                state.term.isEmpty ? '周课表' : state.term,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: [
          IconButton(
            tooltip: '添加课程',
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: '自定义课表背景',
            onPressed: () => _showBackgroundOptions(state),
            icon: const Icon(Icons.wallpaper_outlined),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: state.refreshing
                ? null
                : () => _refreshOrLogin(context, state),
            icon: state.refreshing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                          Theme.of(context).appBarTheme.foregroundColor ??
                          Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _TimetableBackground(
              imagePath: backgroundImagePath,
              fallbackColor: state.timetableBackground,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 52,
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: hasBackgroundImage
                        ? (context.appTheme.isDark
                              ? Colors.black.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.52))
                        : context.appCard.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: context.appBorder.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _week <= 1
                            ? null
                            : () => setState(() => _week--),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              '第 $_week 周 / 共 $totalWeeks 周',
                              style: TextStyle(
                                color: context.appText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (weekStart != null && weekEnd != null)
                              Text(
                                '${weekStart.month}-${weekStart.day} 至 '
                                '${weekEnd.month}-${weekEnd.day}',
                                style: TextStyle(
                                  color: context.appMuted,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: _overview ? '按天查看' : '一周总览',
                        onPressed: () => setState(() => _overview = !_overview),
                        icon: Icon(
                          _overview
                              ? Icons.view_agenda_outlined
                              : Icons.view_week_outlined,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: _week >= totalWeeks
                            ? null
                            : () => setState(() => _week++),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                if (!_overview)
                  Container(
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: hasBackgroundImage
                          ? (context.appTheme.isDark
                                ? Colors.black.withValues(alpha: 0.24)
                                : Colors.white.withValues(alpha: 0.46))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 5,
                      ),
                      child: Row(
                        children: List.generate(7, (index) {
                          final weekday = index + 1;
                          final selected = weekday == _day;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: primary,
                              backgroundColor: primarySoft,
                              side: BorderSide.none,
                              labelStyle: TextStyle(
                                color: selected
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              label: Text(weekdayShortLabel(weekday)),
                              onSelected: (_) => setState(() => _day = weekday),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                Expanded(
                  child: RepaintBoundary(
                    child: _overview
                        ? _buildOverview(state, weekCourses)
                        : _buildDay(state, dayCourses),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasBackgroundImage(AppState state) {
    final path = state.settings.timetableBackgroundImagePath;
    return path != null && path.isNotEmpty && File(path).existsSync();
  }

  int _totalWeeks(AppState state) {
    var totalWeeks = 19;
    for (final course in state.courses) {
      for (final week in course.weeks) {
        if (week > totalWeeks) {
          totalWeeks = week;
        }
      }
    }
    return totalWeeks;
  }

  Future<void> _showBackgroundOptions(AppState state) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.appCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('从相册选择背景'),
                subtitle: const Text('图片会铺满整个周课表'),
                onTap: () => Navigator.pop(sheetContext, 'pick'),
              ),
              if (state.settings.timetableBackgroundImagePath != null)
                ListTile(
                  leading: const Icon(Icons.layers_clear_outlined),
                  title: const Text('恢复纯色背景'),
                  onTap: () => Navigator.pop(sheetContext, 'clear'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'clear') {
      await state.setTimetableBackgroundImage(null);
      return;
    }
    if (action == 'pick') {
      try {
        final image = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1800,
          imageQuality: 82,
        );
        if (image != null) {
          if (mounted) {
            await precacheImage(FileImage(File(image.path)), context);
          }
          await state.setTimetableBackgroundImage(image.path);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('选择背景图片失败：$error')));
        }
      }
    }
  }

  Widget _buildOverview(AppState state, List<Course> weekCourses) {
    final primary = Theme.of(context).colorScheme.primary;
    final primarySoft = Theme.of(context).colorScheme.primaryContainer;
    final customTheme = Theme.of(context).extension<AppCustomTheme>();
    final timetableBackground =
        customTheme?.timetableBackground ?? Colors.white;
    final hasBackgroundImage = _hasBackgroundImage(state);
    final weekStart = termStartDate(
      state.term,
      firstWeekStart: state.settings.firstWeekStarts[state.term],
    )?.add(Duration(days: (_week - 1) * 7));
    final today = dateOnly(DateTime.now());

    String periodTime(int period) {
      return periodTimeRange(period);
    }

    bool isTodayColumn(int weekday) {
      final date = weekStart?.add(Duration(days: weekday - 1));
      return date != null && dateOnly(date) == today;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const timeWidth = 46.0;
        const headerHeight = 58.0;
        const rowCount = 13;
        final rowHeight = ((constraints.maxHeight - headerHeight) / rowCount)
            .clamp(48.0, 72.0);
        final dayWidth = ((constraints.maxWidth - timeWidth) / 7).clamp(
          43.0,
          104.0,
        );
        final gridWidth = timeWidth + dayWidth * 7;
        final gridHeight = rowHeight * rowCount;
        final gridBorder = hasBackgroundImage
            ? context.appBorder.withValues(alpha: 0.45)
            : AppColors.border;
        Widget courseBlock(Course course) {
          final color = course.colorValue != null
              ? Color(course.colorValue!)
              : courseColorOptions[course.name.hashCode.abs() %
                    courseColorOptions.length];
          final spans = course.endPeriod - course.startPeriod + 1;
          return GestureDetector(
            onTap: () => _openEditor(course),
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: course.isCustom ? primary : Colors.white,
                  width: course.isCustom ? 1.4 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.name,
                    maxLines: spans >= 2 ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: dayWidth < 52 ? 8.5 : 9.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (spans >= 2 && course.location != '未标注') ...[
                    const SizedBox(height: 3),
                    Text(
                      course.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: dayWidth < 52 ? 7.5 : 8.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _refreshOrLogin(context, state),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: SingleChildScrollView(
                key: const PageStorageKey('week-grid-horizontal'),
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: gridWidth,
                  child: Column(
                    children: [
                      SizedBox(
                        height: headerHeight,
                        child: Row(
                          children: [
                            SizedBox(
                              width: timeWidth,
                              child: Center(
                                child: Text(
                                  '节次',
                                  style: TextStyle(
                                    color: context.appMuted,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            ...List.generate(7, (index) {
                              final weekday = index + 1;
                              final date = weekStart?.add(
                                Duration(days: index),
                              );
                              final active = isTodayColumn(weekday);
                              return Container(
                                width: dayWidth,
                                decoration: BoxDecoration(
                                  color: active
                                      ? primarySoft.withValues(alpha: 0.72)
                                      : Colors.transparent,
                                  border: Border(
                                    left: BorderSide(color: gridBorder),
                                    bottom: BorderSide(color: gridBorder),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      weekdayShortLabel(weekday)
                                          .replaceFirst('周', ''),
                                      style: TextStyle(
                                        color: active
                                            ? primary
                                            : context.appText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      date == null
                                          ? '--'
                                          : '${date.month}-${date.day}',
                                      style: TextStyle(
                                        color: context.appMuted,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          key: const PageStorageKey('week-grid-vertical'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            width: gridWidth,
                            height: gridHeight,
                            child: Container(
                              color: hasBackgroundImage
                                  ? Colors.transparent
                                  : timetableBackground,
                              child: Stack(
                                children: [
                                  Column(
                                    children: List.generate(rowCount, (
                                      rowIndex,
                                    ) {
                                      final period = rowIndex + 1;
                                      return SizedBox(
                                        height: rowHeight,
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: timeWidth,
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    '$period',
                                                    style: TextStyle(
                                                      color: context.appText,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    periodTime(period),
                                                    style: TextStyle(
                                                      color: context.appMuted,
                                                      fontSize: 6.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ...List.generate(7, (dayIndex) {
                                              final weekday = dayIndex + 1;
                                              return Container(
                                                width: dayWidth,
                                                decoration: BoxDecoration(
                                                  color: isTodayColumn(weekday)
                                                      ? primarySoft.withValues(
                                                          alpha: 0.45,
                                                        )
                                                      : Colors.transparent,
                                                  border: Border(
                                                    left: BorderSide(
                                                      color: gridBorder,
                                                    ),
                                                    bottom: BorderSide(
                                                      color: gridBorder,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                  ...weekCourses.map((course) {
                                    final top =
                                        (course.startPeriod - 1) * rowHeight;
                                    final height =
                                        (course.endPeriod -
                                            course.startPeriod +
                                            1) *
                                        rowHeight;
                                    final left =
                                        timeWidth +
                                        (course.weekday - 1) * dayWidth;
                                    return Positioned(
                                      left: left,
                                      top: top,
                                      width: dayWidth,
                                      height: height,
                                      child: courseBlock(course),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshOrLogin(BuildContext context, AppState state) async {
    if (state.needsLogin) {
      return;
    }
    await state.refreshNow();
  }

  Widget _buildDay(AppState state, List<Course> courses) {
    return RefreshIndicator(
      onRefresh: () => _refreshOrLogin(context, state),
      child: ListView(
        key: const PageStorageKey('week-day-list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 92),
        children: [
          Row(
            children: [
              Text(
                '${weekdayLongLabel(_day)} · 第$_week周',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${courses.length} 节',
                style: TextStyle(color: context.appMuted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (courses.isEmpty)
            const EmptyState(
              title: '这一天没有课程',
              subtitle: '切换星期或教学周查看其他安排',
              icon: Icons.event_available_outlined,
            )
          else
            ...courses.map(
              (course) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CourseCard(
                  course: course,
                  onTap: () => _openEditor(course),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditor([Course? course]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => CourseEditorScreen(initial: course)),
    );
  }
}

class _TimetableBackground extends StatelessWidget {
  const _TimetableBackground({
    required this.imagePath,
    required this.fallbackColor,
  });

  final String? imagePath;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    final file = path == null || path.isEmpty ? null : File(path);
    if (file == null || !file.existsSync()) {
      return ColoredBox(color: fallbackColor);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final pixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = (constraints.maxWidth * pixelRatio)
            .round()
            .clamp(480, 2000)
            .toInt();
        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => ColoredBox(color: fallbackColor),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    context.appTheme.isDark
                        ? Colors.black.withValues(alpha: 0.30)
                        : fallbackColor.withValues(alpha: 0.25),
                    context.appTheme.isDark
                        ? Colors.black.withValues(alpha: 0.42)
                        : fallbackColor.withValues(alpha: 0.36),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
