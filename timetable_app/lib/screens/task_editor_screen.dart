import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_palette.dart';
import '../models/schedule_task.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, this.initial});

  final ScheduleTask? initial;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late DateTime _startAt;
  late DateTime _endAt;
  late int _reminderMinutes;
  String? _imagePath;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    final now = DateTime.now();
    _startAt = initial?.startAt ?? now.add(const Duration(hours: 1));
    _endAt = initial?.endAt ?? _startAt.add(const Duration(hours: 1));
    _reminderMinutes = initial?.reminderMinutes ?? 30;
    _imagePath = initial?.imagePath;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final current = isStart ? _startAt : _endAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) {
      return;
    }
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startAt = value;
        if (_endAt.isBefore(_startAt)) {
          _endAt = _startAt.add(const Duration(hours: 1));
        }
      } else {
        _endAt = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_endAt.isAfter(_startAt)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间')));
      return;
    }
    setState(() => _saving = true);
    final task = ScheduleTask(
      id:
          widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      note: _noteController.text.trim(),
      startAt: _startAt,
      endAt: _endAt,
      reminderMinutes: _reminderMinutes,
      createdAt: widget.initial?.createdAt ?? DateTime.now(),
      imagePath: _imagePath,
    );
    await context.read<AppState>().saveTask(task);
    if (mounted) {
      Navigator.pop(context, task);
    }
  }

  Future<void> _delete() async {
    final initial = widget.initial;
    if (initial == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确定删除“${initial.title}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AppState>().deleteTask(initial.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 85,
    );
    if (image == null || !mounted) {
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final target =
        '${directory.path}/task_${DateTime.now().microsecondsSinceEpoch}.jpg';
    await image.saveTo(target);
    if (mounted) {
      setState(() => _imagePath = target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑日程' : '添加日程'),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                children: [
                  TextFormField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      prefixIcon: Icon(Icons.assignment_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入日程标题';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '备注（可选）',
                      prefixIcon: Icon(Icons.notes_outlined),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (_imagePath != null && File(_imagePath!).existsSync()) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_imagePath!),
                        width: double.infinity,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(_imagePath == null ? '添加提醒图片' : '更换提醒图片'),
                        ),
                      ),
                      if (_imagePath != null) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: '移除图片',
                          onPressed: () => setState(() => _imagePath = null),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.appCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.appBorder),
              ),
              child: Column(
                children: [
                  _DateTimeTile(
                    label: '开始时间',
                    value: _formatDateTime(_startAt),
                    icon: Icons.play_circle_outline,
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                  const Divider(height: 24),
                  _DateTimeTile(
                    label: '结束时间',
                    value: _formatDateTime(_endAt),
                    icon: Icons.stop_circle_outlined,
                    onTap: () => _pickDateTime(isStart: false),
                  ),
                  const Divider(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.notifications_active_outlined,
                      color: primary,
                    ),
                    title: const Text('提醒时间'),
                    trailing: DropdownButton<int>(
                      value: _reminderMinutes,
                      underline: const SizedBox.shrink(),
                      items:
                          const [
                                (value: -1, label: '不提醒'),
                                (value: 0, label: '开始时'),
                                (value: 10, label: '提前10分钟'),
                                (value: 30, label: '提前30分钟'),
                                (value: 60, label: '提前1小时'),
                                (value: 180, label: '提前3小时'),
                                (value: 1440, label: '提前1天'),
                              ]
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.value,
                                  child: Text(item.label),
                                ),
                              )
                              .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _reminderMinutes = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(_isEditing ? '保存修改' : '添加日程'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}年${value.month}月${value.day}日 $hour:$minute';
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: primary),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
