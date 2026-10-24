import 'package:flutter/material.dart';

import '../app_palette.dart';
import '../models/inspiration_entry.dart';
import '../services/inspiration_store.dart';

class InspirationScreen extends StatefulWidget {
  const InspirationScreen({super.key});

  @override
  State<InspirationScreen> createState() => _InspirationScreenState();
}

class _InspirationScreenState extends State<InspirationScreen> {
  final InspirationStore _store = InspirationStore();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<InspirationEntry> _entries = const [];
  String? _editingId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entries = await _store.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      _showMessage('先写下一句想法吧');
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final editingIndex = _entries.indexWhere((entry) => entry.id == _editingId);
    final updated = [..._entries];
    if (editingIndex >= 0) {
      updated[editingIndex] = updated[editingIndex].copyWith(
        content: content,
        updatedAt: now,
      );
    } else {
      updated.insert(
        0,
        InspirationEntry(
          id: now.microsecondsSinceEpoch.toString(),
          content: content,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    updated.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    try {
      await _store.save(updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = updated;
        _editingId = null;
        _controller.clear();
      });
      _focusNode.unfocus();
      _showMessage(editingIndex >= 0 ? '灵感已更新' : '灵感已保存');
    } catch (_) {
      if (mounted) {
        _showMessage('保存失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _edit(InspirationEntry entry) {
    setState(() {
      _editingId = entry.id;
      _controller.text = entry.content;
      _controller.selection = TextSelection.collapsed(
        offset: entry.content.length,
      );
    });
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
    _focusNode.requestFocus();
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _controller.clear();
    });
    _focusNode.unfocus();
  }

  Future<void> _delete(InspirationEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除这条灵感？'),
        content: const Text('删除后无法恢复。'),
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
    final updated = _entries.where((item) => item.id != entry.id).toList();
    await _store.save(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _entries = updated;
      if (_editingId == entry.id) {
        _editingId = null;
        _controller.clear();
      }
    });
    _showMessage('灵感已删除');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('每日灵感')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildComposer(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      '灵感记录',
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_entries.length} 条',
                      style: TextStyle(color: context.appMuted, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_entries.isEmpty)
                  _buildEmptyState()
                else
                  ..._entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _InspirationCard(
                        entry: entry,
                        editing: entry.id == _editingId,
                        onEdit: () => _edit(entry),
                        onDelete: () => _delete(entry),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final primary = Theme.of(context).colorScheme.primary;
    final background = context.appTheme.isDark
        ? const Color(0xFF161616)
        : primary;
    return Container(
      padding: const EdgeInsets.all(20),
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
                  '${now.month}月${now.day}日 · ${_weekday(now.weekday)}',
                  style: const TextStyle(
                    color: Color(0xFFD9E9FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '把闪现的想法留下来',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '一句念头、一个计划，或今天突然想到的答案。',
                  style: TextStyle(
                    color: Color(0xFFD9E9FF),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white.withValues(alpha: 0.9),
            size: 42,
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _editingId == null
              ? context.appBorder
              : primary.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: primary, size: 21),
              const SizedBox(width: 8),
              Text(
                _editingId == null ? '记录此刻的想法' : '正在编辑灵感',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_editingId != null) ...[
                const Spacer(),
                TextButton(onPressed: _cancelEdit, child: const Text('取消编辑')),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              expands: true,
              minLines: null,
              maxLines: null,
              maxLength: 4000,
              textAlignVertical: TextAlignVertical.top,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: '例如：想做一个能自动整理课表和日程的小工具……',
                alignLabelWithHint: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _saving
                    ? '保存中'
                    : _editingId == null
                    ? '保存灵感'
                    : '更新灵感',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 34),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.tips_and_updates_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            '还没有灵感记录',
            style: TextStyle(
              color: context.appText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '第一条想法，也许就是下一件想做的事。',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _weekday(int weekday) {
    return const ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'][weekday - 1];
  }
}

class _InspirationCard extends StatelessWidget {
  const _InspirationCard({
    required this.entry,
    required this.editing,
    required this.onEdit,
    required this.onDelete,
  });

  final InspirationEntry entry;
  final bool editing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: editing ? primary.withValues(alpha: 0.45) : context.appBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatDate(entry.createdAt),
                  style: TextStyle(
                    color: context.appMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '编辑',
                onPressed: onEdit,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 19,
                  color: context.appMuted,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '删除',
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: context.appMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectionArea(
            child: Text(
              entry.content,
              style: TextStyle(
                color: context.appText,
                fontSize: 14,
                height: 1.65,
              ),
            ),
          ),
          if (entry.updatedAt.difference(entry.createdAt).inMinutes >= 1) ...[
            const SizedBox(height: 8),
            Text(
              '更新于 ${_formatTime(entry.updatedAt)}',
              style: TextStyle(color: context.appMuted, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final now = DateTime.now();
    if (_sameDay(value, now)) {
      return '今天 ${_formatTime(value)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_sameDay(value, yesterday)) {
      return '昨天 ${_formatTime(value)}';
    }
    if (value.year == now.year) {
      return '${value.month}月${value.day}日 ${_formatTime(value)}';
    }
    return '${value.year}年${value.month}月${value.day}日';
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _formatTime(DateTime value) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
}
