import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_palette.dart';
import '../app_state.dart';
import '../app_theme.dart';
import '../models/schedule_task.dart';
import '../services/schedule_utils.dart';
import '../services/utility_client.dart';
import '../widgets/course_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/utility_usage_sparkline.dart';
import 'course_editor_screen.dart';
import 'empty_classroom_screen.dart';
import 'inspiration_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onOpenUtility});

  final VoidCallback? onOpenUtility;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();
    final todayCourses = state.todayCourses;
    final activeTasks = state.tasks
        .where((task) => task.endAt.isAfter(now))
        .take(5)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('重外小助手'),
        actions: [
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
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshOrLogin(context, state),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            _CompactTodayHeader(
              week: state.currentWeek,
              dateLabel:
                  '${now.month}月${now.day}日 ${weekdayLongLabel(now.weekday)}',
              courseCount: todayCourses.length,
              taskCount: activeTasks.length,
            ),
            if (!state.loggedIn) ...[
              const SizedBox(height: 12),
              _GuestModeBanner(onLogin: () => _openLogin(context)),
            ],
            if (!state.sessionExpired && state.cacheReminderDue) ...[
              const SizedBox(height: 12),
              _CacheReminderBanner(
                ageDays: state.cacheAgeDays ?? 0,
                onLogin: () => _openLogin(context),
              ),
            ] else if (!state.sessionExpired && state.error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(message: state.error!),
            ],
            const SizedBox(height: 22),
            _SectionTitle(title: '今日课程', trailing: '${todayCourses.length} 节'),
            const SizedBox(height: 10),
            if (todayCourses.isEmpty)
              const EmptyState(
                title: '今天没有课程',
                subtitle: '可以切换到“周课表”查看其他安排',
                icon: Icons.wb_sunny_outlined,
              )
            else
              ...todayCourses.map(
                (course) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: CourseCard(
                    course: course,
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => CourseEditorScreen(initial: course),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (activeTasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SectionTitle(
                title: '日程倒计时',
                trailingWidget: TextButton(
                  onPressed: () => _openPage(context, const TasksScreen()),
                  child: const Text('查看全部'),
                ),
              ),
              const SizedBox(height: 10),
              ...activeTasks.map(
                (task) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HomeTaskCard(task: task),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _InspirationHomeCard(
              onTap: () => _openPage(context, const InspirationScreen()),
            ),
            const SizedBox(height: 20),
            _UtilityBalanceSection(
              snapshot: state.utilitySnapshot,
              history: state.utilityHistory,
              onTap: onOpenUtility,
            ),
            const SizedBox(height: 20),
            const _SectionTitle(title: '快捷功能', trailing: '更多工具'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                _QuickAction(
                  icon: Icons.map_outlined,
                  label: '校园地图',
                  onTap: () => _openPage(context, const MapScreen()),
                ),
                _QuickAction(
                  icon: Icons.assignment_outlined,
                  label: '日程',
                  onTap: () => _openPage(context, const TasksScreen()),
                ),
                _QuickAction(
                  icon: Icons.sync_rounded,
                  label: '刷新课表',
                  onTap: () => _refreshOrLogin(context, state),
                ),
                _QuickAction(
                  icon: Icons.meeting_room_outlined,
                  label: '教室课表',
                  onTap: () => _openPage(context, const EmptyClassroomScreen()),
                ),
                _QuickAction(
                  icon: Icons.settings_outlined,
                  label: '设置',
                  onTap: () => _openPage(context, const SettingsScreen()),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (state.lastUpdated != null)
              Text(
                '课表缓存 ${_formatTime(state.lastUpdated!)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appMuted, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _refreshOrLogin(BuildContext context, AppState state) async {
    if (state.needsLogin) {
      return;
    }
    await state.refreshNow();
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}月${value.day}日 $hour:$minute';
  }
}

class _CompactTodayHeader extends StatelessWidget {
  const _CompactTodayHeader({
    required this.week,
    required this.dateLabel,
    required this.courseCount,
    required this.taskCount,
  });

  final int week;
  final String dateLabel;
  final int courseCount;
  final int taskCount;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final background = context.appTheme.isDark
        ? const Color(0xFF151515)
        : primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第$week周',
                  style: const TextStyle(
                    color: Color(0xFFD8E9FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  dateLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$courseCount 节课程 · $taskCount 个日程',
                  style: const TextStyle(
                    color: Color(0xFFD8E9FF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.calendar_month_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 38,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    this.trailing,
    this.trailingWidget,
  });

  final String title;
  final String? trailing;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.appText,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (trailingWidget != null)
          trailingWidget!
        else if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(color: context.appMuted, fontSize: 12),
          ),
      ],
    );
  }
}

class _UtilityBalanceSection extends StatelessWidget {
  const _UtilityBalanceSection({
    required this.snapshot,
    required this.history,
    required this.onTap,
  });

  final UtilitySnapshot? snapshot;
  final List<UtilityHistoryPoint> history;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '水电余额',
              style: TextStyle(
                color: context.appText,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            TextButton(onPressed: onTap, child: const Text('查看详情')),
          ],
        ),
        const SizedBox(height: 8),
        if (snapshot == null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.appBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.water_drop_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '还没有水电余额，前往水电页完成微信授权',
                        style: TextStyle(color: context.appMuted, fontSize: 12),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.appMuted),
                  ],
                ),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _HomeBalanceCard(
                  icon: Icons.water_drop_outlined,
                  accent: const Color(0xFF1687D9),
                  label: '水表',
                  remaining: '${snapshot!.waterRemaining.toStringAsFixed(2)} 吨',
                  balance: '¥${snapshot!.waterBalance.toStringAsFixed(2)}',
                  onTap: onTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeBalanceCard(
                  icon: Icons.bolt_rounded,
                  accent: const Color(0xFFE69B16),
                  label: '电表',
                  remaining:
                      '${snapshot!.electricityRemaining.toStringAsFixed(2)} 度',
                  balance:
                      '¥${snapshot!.electricityBalance.toStringAsFixed(2)}',
                  onTap: onTap,
                ),
              ),
            ],
          ),
        if (snapshot != null) ...[
          const SizedBox(height: 12),
          _HomeUtilityTrendCard(history: history, onTap: onTap),
        ],
      ],
    );
  }
}

class _HomeUtilityTrendCard extends StatelessWidget {
  const _HomeUtilityTrendCard({required this.history, required this.onTap});

  final List<UtilityHistoryPoint> history;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final visible = history.length > 20
        ? history.sublist(history.length - 20)
        : history;
    final waterValues = visible.map((item) => item.waterRemaining).toList();
    final electricityValues = visible
        .map((item) => item.electricityRemaining)
        .toList();
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
                  Icon(
                    Icons.show_chart_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '水电用量趋势',
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    visible.length < 2 ? '继续刷新生成趋势' : '查看详情',
                    style: TextStyle(color: context.appMuted, fontSize: 10),
                  ),
                ],
              ),
              if (visible.length < 2)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '刷新水电数据两次以上后，首页会显示用量曲线。',
                    style: TextStyle(
                      color: context.appMuted,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _HomeTrendSide(
                          label: '水',
                          values: waterValues,
                          start: visible.first.recordedAt,
                          end: visible.last.recordedAt,
                          color: const Color(0xFF1687D9),
                          unit: '吨/天',
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: _HomeTrendSide(
                          label: '电',
                          values: electricityValues,
                          start: visible.first.recordedAt,
                          end: visible.last.recordedAt,
                          color: const Color(0xFFE69B16),
                          unit: '度/天',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTrendSide extends StatelessWidget {
  const _HomeTrendSide({
    required this.label,
    required this.values,
    required this.start,
    required this.end,
    required this.color,
    required this.unit,
  });

  final String label;
  final List<double> values;
  final DateTime start;
  final DateTime end;
  final Color color;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final dailyUsage = _dailyUsage(values, start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        UtilityUsageSparkline(
          values: values,
          color: color,
          gridColor: context.appBorder,
          height: 58,
        ),
        const SizedBox(height: 5),
        Text(
          dailyUsage > 0 ? '${dailyUsage.toStringAsFixed(2)} $unit' : '持续消耗不足',
          style: TextStyle(color: context.appMuted, fontSize: 9),
        ),
      ],
    );
  }

  double _dailyUsage(List<double> values, DateTime start, DateTime end) {
    final hours = end.difference(start).inMinutes / 60;
    if (values.length < 2 || values.first <= values.last || hours <= 0) {
      return 0;
    }
    return (values.first - values.last) / (hours / 24);
  }
}

class _HomeBalanceCard extends StatelessWidget {
  const _HomeBalanceCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.remaining,
    required this.balance,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String label;
  final String remaining;
  final String balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
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
                  Icon(icon, color: accent, size: 21),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(color: context.appMuted, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                remaining,
                style: TextStyle(
                  color: context.appText,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '余额 $balance',
                style: TextStyle(color: context.appMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final primarySoft = Theme.of(context).colorScheme.primaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primary, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _InspirationHomeCard extends StatelessWidget {
  const _InspirationHomeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = context.appTheme.isDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1C1C1C), const Color(0xFF111111)]
                  : [
                      primary,
                      Color.alphaBlend(
                        Colors.black.withValues(alpha: 0.16),
                        primary,
                      ),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '每日灵感',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      '记录此刻的想法，留住每一个突然出现的念头',
                      style: TextStyle(
                        color: Color(0xFFD9E9FF),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTaskCard extends StatelessWidget {
  const _HomeTaskCard({required this.task});

  final ScheduleTask task;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_outlined, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.countdownLabel(now),
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${task.endAt.month}-${task.endAt.day}',
            style: TextStyle(color: context.appMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GuestModeBanner extends StatelessWidget {
  const _GuestModeBanner({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.explore_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '游客模式',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '课表、地图和日程可直接使用',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onLogin, child: const Text('登录')),
        ],
      ),
    );
  }
}

class _CacheReminderBanner extends StatelessWidget {
  const _CacheReminderBanner({required this.ageDays, required this.onLogin});

  final int ageDays;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD58A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.update_outlined, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '课表缓存已 $ageDays 天，建议重新登录更新',
              style: const TextStyle(color: AppColors.warning, fontSize: 12),
            ),
          ),
          TextButton(onPressed: onLogin, child: const Text('去更新')),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFAA2424)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFAA2424), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
