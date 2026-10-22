import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_palette.dart';
import '../models/course.dart';
import '../services/schedule_utils.dart';

class CourseEditorScreen extends StatefulWidget {
  const CourseEditorScreen({super.key, this.initial});

  final Course? initial;

  @override
  State<CourseEditorScreen> createState() => _CourseEditorScreenState();
}

class _CourseEditorScreenState extends State<CourseEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _teacherController;
  late final TextEditingController _locationController;
  late int _weekday;
  late int _startPeriod;
  late int _endPeriod;
  late int _startWeek;
  late int _endWeek;
  late int _selectedColorValue;
  bool _saving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _teacherController = TextEditingController(
      text: initial?.teacher == '未标注' ? '' : initial?.teacher ?? '',
    );
    _locationController = TextEditingController(
      text: initial?.location == '未标注' ? '' : initial?.location ?? '',
    );
    _weekday = initial?.weekday ?? 1;
    _startPeriod = initial?.startPeriod ?? 1;
    _endPeriod = initial?.endPeriod ?? 2;
    _startWeek = initial?.weeks.isNotEmpty == true
        ? initial!.weeks.reduce((left, right) => left < right ? left : right)
        : 1;
    _endWeek = initial?.weeks.isNotEmpty == true
        ? initial!.weeks.reduce((left, right) => left > right ? left : right)
        : 16;
    _selectedColorValue =
        initial?.colorValue ?? courseColorOptions.first.toARGB32();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _teacherController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_endPeriod < _startPeriod) {
      _showMessage('结束节次不能早于开始节次');
      return;
    }
    if (_endWeek < _startWeek) {
      _showMessage('结束周不能早于开始周');
      return;
    }

    setState(() => _saving = true);
    final app = context.read<AppState>();
    final teacher = _teacherController.text.trim();
    final location = _locationController.text.trim();
    final periods = _startPeriod == _endPeriod
        ? '第$_startPeriod节'
        : '第$_startPeriod-$_endPeriod节';
    final course = Course(
      id:
          widget.initial?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      teacher: teacher.isEmpty ? '未标注' : teacher,
      location: location.isEmpty ? '未标注' : location,
      weekday: _weekday,
      startPeriod: _startPeriod,
      endPeriod: _endPeriod,
      weeks: List.generate(
        _endWeek - _startWeek + 1,
        (index) => _startWeek + index,
      ),
      term: widget.initial?.term.isNotEmpty == true
          ? widget.initial!.term
          : app.term,
      timeText:
          '${weekdayLongLabel(_weekday)} $periods 第$_startWeek-$_endWeek周',
      displayTime: '自定义课程',
      weekPeriodRaw: '$_startWeek-$_endWeek周',
      isCustom: true,
      colorValue: _selectedColorValue,
    );
    final original = widget.initial;
    if (original == null) {
      await app.saveCustomCourse(course);
    } else {
      await app.saveCourseChange(original: original, updated: course);
    }
    if (!mounted) {
      return;
    }
    Navigator.pop(context, course);
  }

  Future<void> _delete() async {
    final initial = widget.initial;
    if (initial == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除课程'),
        content: Text('确定删除“${initial.name}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await context.read<AppState>().deleteCourse(initial);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑课程' : '添加课程'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: '删除',
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
            _EditorCard(
              title: '课程信息',
              children: [
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '课程名称',
                    prefixIcon: Icon(Icons.book_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入课程名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _teacherController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '老师（可选）',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _locationController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: '地点（可选）',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '课程颜色',
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
                  children: courseColorOptions.map((color) {
                    final selected = color.toARGB32() == _selectedColorValue;
                    return GestureDetector(
                      onTap: () => setState(
                        () => _selectedColorValue = color.toARGB32(),
                      ),
                      child: Container(
                        width: 34,
                        height: 34,
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
                                size: 18,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EditorCard(
              title: '上课时间',
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _weekday,
                  decoration: const InputDecoration(labelText: '星期'),
                  items: List.generate(
                    7,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text(weekdayLongLabel(index + 1)),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _weekday = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _startPeriod,
                        decoration: const InputDecoration(labelText: '开始节次'),
                        items: List.generate(
                          13,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('第${index + 1}节'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _startPeriod = value;
                              if (_endPeriod < value) {
                                _endPeriod = value;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _endPeriod,
                        decoration: const InputDecoration(labelText: '结束节次'),
                        items: List.generate(
                          13,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('第${index + 1}节'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _endPeriod = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            _EditorCard(
              title: '上课周次',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _startWeek,
                        decoration: const InputDecoration(labelText: '开始周'),
                        items: List.generate(
                          30,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('第${index + 1}周'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _startWeek = value;
                              if (_endWeek < value) {
                                _endWeek = value;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _endWeek,
                        decoration: const InputDecoration(labelText: '结束周'),
                        items: List.generate(
                          30,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text('第${index + 1}周'),
                          ),
                        ),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _endWeek = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
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
                  : Text(_isEditing ? '保存修改' : '添加课程'),
            ),
            const SizedBox(height: 10),
            Text(
              '自定义课程仅保存在本机，不会修改学校教务系统。',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
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
              color: primary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
