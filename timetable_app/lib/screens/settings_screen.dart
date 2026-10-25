import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../app_palette.dart';
import '../services/app_settings.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          _SectionCard(
            title: '账号',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primary,
                  child: Icon(Icons.person_outline),
                ),
                title: Text(
                  '教务账号：${state.username ?? '未登录'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  !state.loggedIn
                      ? '游客模式：课表、地图和日程可直接使用'
                      : state.sessionExpired
                      ? '登录状态：已失效，显示本地缓存'
                      : '登录状态：已登录',
                ),
                trailing: state.needsLogin
                    ? TextButton(
                        onPressed: () => _openLogin(context),
                        child: Text(state.loggedIn ? '重新登录' : '登录'),
                      )
                    : null,
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.water_drop_outlined),
                title: const Text('水电账号：微信授权'),
                subtitle: const Text('教务账号登录后，再单独授权二期水电平台'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined),
                title: Text(
                  state.term.isEmpty ? '当前学期：未获取' : '当前学期：${state.term}',
                ),
                subtitle: const Text('数据模式：仅本地缓存，手动更新'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.update_outlined),
                title: const Text('课表缓存时间'),
                subtitle: Text(
                  state.lastUpdated == null
                      ? '暂无缓存'
                      : _formatDateTime(state.lastUpdated!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '界面设置',
            children: [
              Text(
                '界面颜色',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppThemeColor.values.map((color) {
                  final selected = state.settings.themeColor == color;
                  final preview = color.previewColor;
                  return ChoiceChip(
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: preview,
                    backgroundColor: preview.withValues(alpha: 0.18),
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      color: selected
                          ? color.previewForeground
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    label: Text(color.label),
                    onSelected: (_) => state.setThemeColor(color),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                '周课表背景',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: timetableBackgroundOptions.map((color) {
                  final selected =
                      state.settings.timetableBackgroundValue ==
                      color.toARGB32();
                  return GestureDetector(
                    onTap: () => state.setTimetableBackground(color),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : context.appBorder,
                          width: selected ? 2.4 : 1,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check,
                              size: 19,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              Text(
                '周课表背景图片',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '图片会铺满整个周课表，推荐使用竖版、浅色图片。',
                style: TextStyle(color: context.appMuted, fontSize: 11),
              ),
              if (state.settings.timetableBackgroundImagePath != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(state.settings.timetableBackgroundImagePath!),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 80,
                      alignment: Alignment.center,
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: const Text('背景图片已失效，请重新选择'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _pickBackgroundImage(context, state),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: const Text('从相册选择'),
                  ),
                  if (state.settings.timetableBackgroundImagePath != null)
                    TextButton.icon(
                      onPressed: () => state.setTimetableBackgroundImage(null),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('移除图片'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '缓存策略',
            children: [
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.storage_outlined, color: AppColors.primary),
                title: Text('自动联网刷新'),
                subtitle: Text('已关闭，仅使用本地缓存；手动刷新或重新登录时更新'),
                trailing: Text(
                  '手动更新',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('缓存更新提醒'),
                subtitle: const Text('缓存超过设定天数后提醒重新登录更新'),
                value: state.settings.cacheReminderEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (value) async {
                  final error = await state.setCacheReminderEnabled(value);
                  if (context.mounted && error != null) {
                    _showMessage(context, error);
                  }
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提醒间隔'),
                subtitle: Text('已缓存 ${state.cacheAgeDays ?? 0} 天'),
                trailing: DropdownButton<int>(
                  value: state.settings.cacheReminderDays,
                  underline: const SizedBox.shrink(),
                  items: const [1, 3, 7, 14, 30]
                      .map(
                        (days) => DropdownMenuItem(
                          value: days,
                          child: Text('$days 天'),
                        ),
                      )
                      .toList(),
                  onChanged: state.settings.cacheReminderEnabled
                      ? (value) {
                          if (value != null) {
                            state.setCacheReminderDays(value);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '上课提醒',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用上课提醒'),
                subtitle: const Text('提前提醒下一节课'),
                value: state.settings.remindersEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (value) async {
                  final error = await state.setRemindersEnabled(value);
                  if (context.mounted && error != null) {
                    _showMessage(context, error);
                  }
                },
              ),
              const Divider(),
              const SizedBox(height: 8),
              const Text(
                '提醒方式',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<ReminderMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: ReminderMode.notification,
                    icon: Icon(Icons.notifications_outlined),
                    label: Text('推送消息'),
                  ),
                  ButtonSegment(
                    value: ReminderMode.alarm,
                    icon: Icon(Icons.alarm),
                    label: Text('闹钟提醒'),
                  ),
                ],
                selected: {state.settings.reminderMode},
                onSelectionChanged: state.settings.remindersEnabled
                    ? (selection) async {
                        final error = await state.setReminderMode(
                          selection.first,
                        );
                        if (context.mounted && error != null) {
                          _showMessage(context, error);
                        }
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('提前提醒时间'),
                trailing: DropdownButton<int>(
                  value: state.settings.reminderLeadMinutes,
                  underline: const SizedBox.shrink(),
                  items: const [5, 10, 15, 20, 30]
                      .map(
                        (minutes) => DropdownMenuItem(
                          value: minutes,
                          child: Text('$minutes 分钟'),
                        ),
                      )
                      .toList(),
                  onChanged: state.settings.remindersEnabled
                      ? (value) {
                          if (value != null) {
                            state.setReminderLead(value);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '水电余额预警',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用低余额提醒'),
                subtitle: const Text('刷新水电数据后发现余额偏低时通知'),
                value: state.settings.utilityAlertsEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (value) async {
                  final error = await state.setUtilityAlertsEnabled(value);
                  if (context.mounted && error != null) {
                    _showMessage(context, error);
                  }
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('水费提醒阈值'),
                subtitle: const Text('账户余额低于该金额时提醒'),
                trailing: DropdownButton<double>(
                  value: state.settings.waterAlertThreshold,
                  underline: const SizedBox.shrink(),
                  items: const [5.0, 10.0, 20.0, 30.0, 50.0, 100.0]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('¥${value.toStringAsFixed(0)}'),
                        ),
                      )
                      .toList(),
                  onChanged: state.settings.utilityAlertsEnabled
                      ? (value) {
                          if (value != null) {
                            state.setWaterAlertThreshold(value);
                          }
                        }
                      : null,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('电费提醒阈值'),
                subtitle: const Text('账户余额低于该金额时提醒'),
                trailing: DropdownButton<double>(
                  value: state.settings.electricityAlertThreshold,
                  underline: const SizedBox.shrink(),
                  items: const [10.0, 20.0, 30.0, 50.0, 100.0, 200.0]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('¥${value.toStringAsFixed(0)}'),
                        ),
                      )
                      .toList(),
                  onChanged: state.settings.utilityAlertsEnabled
                      ? (value) {
                          if (value != null) {
                            state.setElectricityAlertThreshold(value);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '数据',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.cloud_done_outlined,
                  color: AppColors.primary,
                ),
                title: const Text('立即更新'),
                subtitle: Text(
                  state.lastUpdated == null
                      ? '尚未更新'
                      : '最近更新：${_formatDateTime(state.lastUpdated!)}',
                ),
                trailing: state.refreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: state.refreshing
                    ? null
                    : () => _refreshOrLogin(context, state),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: Color(0xFFAA2424)),
                title: const Text(
                  '退出并清除数据',
                  style: TextStyle(color: Color(0xFFAA2424)),
                ),
                subtitle: const Text('清除登录状态和本地课表缓存'),
                onTap: () => _confirmLogout(context, state),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: '关于',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('重外小助手'),
                subtitle: const Text('版本 2.6.5 · Android + Flutter'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.code_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('GitHub 项目'),
                subtitle: const Text('saberkk3/cqifsAssistant'),
                trailing: const Icon(Icons.open_in_new_rounded),
                onTap: () => _openGithub(context),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  '本软件仅个人使用。验证码需手动输入，'
                  '不保存密码，不绕过学校系统的安全验证。',
                  style: TextStyle(
                    color: context.appMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('将清除登录状态和本地课表，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.logout();
    }
  }

  Future<void> _pickBackgroundImage(
    BuildContext context,
    AppState state,
  ) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 82,
      );
      if (image != null) {
        if (context.mounted) {
          await precacheImage(FileImage(File(image.path)), context);
        }
        await state.setTimetableBackgroundImage(image.path);
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, '选择背景图片失败：$error');
      }
    }
  }

  Future<void> _openGithub(BuildContext context) async {
    final uri = Uri.parse('https://github.com/saberkk3/cqifsAssistant');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        _showMessage(context, '无法打开 GitHub 项目链接');
      }
    } catch (_) {
      if (context.mounted) {
        _showMessage(context, '无法打开 GitHub 项目链接');
      }
    }
  }

  Future<void> _openLogin(BuildContext context) {
    return Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Future<void> _refreshOrLogin(BuildContext context, AppState state) async {
    if (state.needsLogin) {
      await _openLogin(context);
      return;
    }
    await state.refreshNow();
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.month}月${value.day}日 $hour:$minute';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}
