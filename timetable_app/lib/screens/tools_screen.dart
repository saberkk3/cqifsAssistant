import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_palette.dart';
import 'map_screen.dart';
import 'tasks_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _ToolCard(
            icon: Icons.map_outlined,
            title: '校园地图',
            subtitle: '720° 全景校园导览',
            onTap: () => Navigator.of(
              context,
            ).push<void>(MaterialPageRoute(builder: (_) => const MapScreen())),
          ),
          const SizedBox(height: 14),
          _ToolCard(
            icon: Icons.assignment_outlined,
            title: '作业与日程',
            subtitle: state.tasks.isEmpty
                ? '添加作业、考试和自定义倒计时'
                : '已有 ${state.tasks.length} 个日程，点击查看倒计时',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute(builder: (_) => const TasksScreen()),
            ),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: context.appMuted, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '所有工具均为本地功能。水电费自动同步仍需学校开放接口，'
                    '当前可通过微信链接查看。',
                    style: TextStyle(
                      color: context.appMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final primarySoft = Theme.of(context).colorScheme.primaryContainer;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.appCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: primarySoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: context.appMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.appMuted),
            ],
          ),
        ),
      ),
    );
  }
}
