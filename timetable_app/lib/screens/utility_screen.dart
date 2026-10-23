import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_palette.dart';
import '../app_state.dart';
import '../app_theme.dart';
import '../services/utility_client.dart';
import 'login_screen.dart';
import 'utility_meter_screen.dart';

class UtilityScreen extends StatefulWidget {
  const UtilityScreen({super.key});

  @override
  State<UtilityScreen> createState() => _UtilityScreenState();
}

class _UtilityScreenState extends State<UtilityScreen> {
  final UtilityClient _client = UtilityClient();
  bool _busy = false;
  String? _error;

  Future<void> _acceptSnapshot(UtilitySnapshot snapshot) async {
    await context.read<AppState>().saveUtilitySnapshot(snapshot);
    if (mounted) {
      setState(() => _error = null);
    }
  }

  Future<void> _refreshData() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await _client.fetchSnapshot();
      await _acceptSnapshot(snapshot);
    } on UtilityAuthRequiredException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
        await _startAuthorization();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startAuthorization() async {
    if (_busy) {
      return;
    }
    if (!await _ensureAppLogin()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final oauthUrl = await _client.beginAuthorization();
      await Clipboard.setData(ClipboardData(text: oauthUrl));
      if (!mounted) {
        return;
      }
      final snapshot = await showModalBottomSheet<UtilitySnapshot>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.appCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) =>
            _AuthorizationSheet(client: _client, initialUrl: oauthUrl),
      );
      if (snapshot != null) {
        await _acceptSnapshot(snapshot);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<bool> _ensureAppLogin() async {
    final state = context.read<AppState>();
    if (!state.needsLogin) {
      return true;
    }
    final shouldLogin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('先登录教务账号'),
        content: const Text(
          '课表、地图和日程可免登录使用；'
          '授权水电信息前需要先登录教务账号。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('去登录'),
          ),
        ],
      ),
    );
    if (shouldLogin != true || !mounted) {
      return false;
    }
    await Navigator.of(context)
        .push<void>(MaterialPageRoute(builder: (_) => const LoginScreen()));
    if (!mounted) {
      return false;
    }
    return !context.read<AppState>().needsLogin;
  }

  Future<void> _openMeter(UtilityMeterType type) async {
    final snapshot = context.read<AppState>().utilitySnapshot;
    if (snapshot == null) {
      await _startAuthorization();
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UtilityMeterScreen(
          type: type,
          snapshot: snapshot,
          client: _client,
          onSnapshotUpdated: _acceptSnapshot,
        ),
      ),
    );
  }

  Future<void> _openGuide() {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => const UtilityAuthorizationGuideScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = context.watch<AppState>().utilitySnapshot;
    return Scaffold(
      appBar: AppBar(
        title: const Text('水电费'),
        actions: [
          IconButton(
            tooltip: '授权教学',
            onPressed: _openGuide,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            tooltip: '重新授权',
            onPressed: _busy ? null : _startAuthorization,
            icon: const Icon(Icons.verified_user_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            _UtilityHero(snapshot: snapshot),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _MessageCard(
                icon: Icons.info_outline,
                text: _error!,
                color: AppColors.warning,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : snapshot == null
                        ? _startAuthorization
                        : _refreshData,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            snapshot == null
                                ? Icons.link_rounded
                                : Icons.sync_rounded,
                          ),
                    label: Text(snapshot == null ? '微信授权并同步' : '更新数据'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _openGuide,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('授权教学'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (snapshot == null)
              _EmptyUtilityState(onAuthorize: _startAuthorization)
            else ...[
              _MeterEntryCard(
                icon: Icons.water_drop_outlined,
                accent: const Color(0xFF1687D9),
                title: '水表',
                roomName: snapshot.roomName,
                primaryValue: '${snapshot.waterRemaining.toStringAsFixed(2)} 吨',
                secondaryValue:
                    '余额 ¥${snapshot.waterBalance.toStringAsFixed(2)}',
                updatedAt: snapshot.waterMeasuredAt,
                onTap: () => _openMeter(UtilityMeterType.water),
              ),
              const SizedBox(height: 14),
              _MeterEntryCard(
                icon: Icons.bolt_rounded,
                accent: const Color(0xFFE69B16),
                title: '电表',
                roomName: snapshot.roomName,
                primaryValue:
                    '${snapshot.electricityRemaining.toStringAsFixed(2)} 度',
                secondaryValue:
                    '余额 ¥${snapshot.electricityBalance.toStringAsFixed(2)}',
                updatedAt: snapshot.electricityMeasuredAt,
                onTap: () => _openMeter(UtilityMeterType.electricity),
              ),
              const SizedBox(height: 18),
              _MessageCard(
                icon: Icons.shield_outlined,
                text:
                    '水表和电表已拆分为独立页面。充值操作会创建学校官方订单，'
                    '付款前请再次核对房间和金额。',
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class UtilityAuthorizationGuideScreen extends StatelessWidget {
  const UtilityAuthorizationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('水电授权教学')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          Text(
            '授权步骤',
            style: TextStyle(
              color: context.appText,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          const _GuideStep(
            index: '1',
            title: '复制授权链接',
            text: '在水电首页点击“微信授权并同步”，App 会自动复制授权链接。',
          ),
          const _GuideStep(
            index: '2',
            title: '在微信文件传输助手中点开',
            text: '把授权链接发送到微信“文件传输助手”，然后直接点开链接。',
          ),
          const _GuideStep(
            index: '3',
            title: '选择在浏览器中打开',
            text:
                '出现 tcsisu.educationgroup.cn 的 404 页面后，点击右上角“…”，'
                '选择“在浏览器中打开”。',
          ),
          const _GuideStep(
            index: '4',
            title: '复制网址并回到 App',
            text:
                '在浏览器菜单中选择“复制网址”，回到 App 粘贴，'
                'App 会自动登录并同步水电数据。',
          ),
          const SizedBox(height: 10),
          const _GuideScreenshot(
            assetPath: 'assets/guide/utility_auth_1.jpg',
            title: '1. 在文件传输助手中点开链接',
          ),
          const SizedBox(height: 14),
          const _GuideScreenshot(
            assetPath: 'assets/guide/utility_auth_2.jpg',
            title: '2. 404 页面点击右上角',
          ),
          const SizedBox(height: 14),
          const _GuideScreenshot(
            assetPath: 'assets/guide/utility_auth_3.jpg',
            title: '3. 选择“在浏览器中打开”',
          ),
          const SizedBox(height: 14),
          const _GuideScreenshot(
            assetPath: 'assets/guide/utility_auth_4.jpg',
            title: '4. 在浏览器菜单中复制网址',
          ),
          const SizedBox(height: 16),
          _MessageCard(
            icon: Icons.lock_outline,
            text:
                '授权码只用于本次学校水电平台登录，不上传账号密码，'
                '也不会写入课表或日程数据。',
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({
    required this.index,
    required this.title,
    required this.text,
  });

  final String index;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              index,
              style: TextStyle(
                color: primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: context.appMuted,
                    fontSize: 12,
                    height: 1.5,
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

class _GuideScreenshot extends StatelessWidget {
  const _GuideScreenshot({required this.assetPath, required this.title});

  final String assetPath;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: context.appText,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              assetPath,
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
        ],
      ),
    );
  }
}

class _UtilityHero extends StatelessWidget {
  const _UtilityHero({required this.snapshot});

  final UtilitySnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final heroColor = context.appTheme.isDark
        ? const Color(0xFF171717)
        : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: heroColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.appTheme.isDark
              ? context.appBorder
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(
              Icons.electric_meter_outlined,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot?.roomName.isNotEmpty == true
                      ? snapshot!.roomName
                      : '二期水电平台',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  snapshot == null
                      ? '完成微信授权后查看水表和电表'
                      : '${snapshot!.realName} · ${snapshot!.studentNumber}',
                  style: const TextStyle(
                    color: Color(0xFFDCEBFF),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (snapshot != null)
            Text(
              _formatDateTime(snapshot!.updatedAt),
              style: const TextStyle(color: Color(0xFFC4D9F4), fontSize: 10),
            ),
        ],
      ),
    );
  }
}

class _MeterEntryCard extends StatelessWidget {
  const _MeterEntryCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.roomName,
    required this.primaryValue,
    required this.secondaryValue,
    required this.updatedAt,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String roomName;
  final String primaryValue;
  final String secondaryValue;
  final DateTime updatedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: accent, size: 29),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: context.appText,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          roomName,
                          style: TextStyle(
                            color: context.appMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      primaryValue,
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$secondaryValue · 采集 ${_formatDateTime(updatedAt)}',
                      style: TextStyle(color: context.appMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: context.appMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyUtilityState extends StatelessWidget {
  const _EmptyUtilityState({required this.onAuthorize});

  final VoidCallback onAuthorize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Icon(
            Icons.water_drop_outlined,
            color: Theme.of(context).colorScheme.primary,
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            '还没有水电数据',
            style: TextStyle(
              color: context.appText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '完成一次微信授权后，水表和电表会分别显示在独立页面。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appMuted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAuthorize,
            icon: const Icon(Icons.link_rounded),
            label: const Text('开始授权'),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
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
        ],
      ),
    );
  }
}

class _AuthorizationSheet extends StatefulWidget {
  const _AuthorizationSheet({required this.client, required this.initialUrl});

  final UtilityClient client;
  final String initialUrl;

  @override
  State<_AuthorizationSheet> createState() => _AuthorizationSheetState();
}

class _AuthorizationSheetState extends State<_AuthorizationSheet>
    with WidgetsBindingObserver {
  final TextEditingController _callbackController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callbackController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_readClipboardCallback());
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(ClipboardData(text: widget.initialUrl));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('授权链接已复制')));
    }
  }

  Future<void> _openWeChat() async {
    await Clipboard.setData(ClipboardData(text: widget.initialUrl));
    try {
      final opened = await launchUrl(
        Uri.parse('weixin://'),
        mode: LaunchMode.externalApplication,
      );
      if (opened) {
        if (mounted) {
          setState(() {
            _error = '微信已打开。请把刚复制的授权链接发送到文件传输助手并点开。';
          });
        }
        return;
      }
    } catch (_) {
      // Keep the clipboard fallback below.
    }
    if (mounted) {
      setState(() {
        _error = '无法直接打开微信，授权链接已复制，请手动发送到微信中打开。';
      });
    }
  }

  Future<void> _readClipboardCallback({bool showError = false}) async {
    if (_busy) {
      return;
    }
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!text.startsWith('https://tcsisu.educationgroup.cn/') ||
        !text.contains('code=')) {
      if (showError && mounted) {
        setState(() => _error = '剪贴板中没有检测到微信授权回调链接');
      }
      return;
    }
    _callbackController.text = text;
    await _complete();
  }

  Future<void> _complete() async {
    final value = _callbackController.text.trim();
    if (value.isEmpty) {
      setState(() => _error = '请粘贴微信授权后的完整链接');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final snapshot = await widget.client.completeAuthorization(value);
      if (mounted) {
        Navigator.pop(context, snapshot);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + keyboard),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appBorder,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '微信授权水电账号',
              style: TextStyle(
                color: context.appText,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '首次使用需要完成一次微信授权。授权成功后，'
              'App 会在本机保存绑定参数并自动恢复水电登录，之后无需反复授权。'
              '返回 App 时也会自动识别剪贴板回调。',
              style: TextStyle(
                color: context.appMuted,
                fontSize: 12,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _openWeChat,
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('打开微信授权'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _copyUrl,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                  label: const Text('复制链接'),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _readClipboardCallback(showError: true),
                icon: const Icon(Icons.content_paste_search_outlined, size: 18),
                label: const Text('粘贴并验证回调'),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                widget.initialUrl,
                maxLines: 5,
                style: TextStyle(
                  color: context.appText,
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _copyUrl,
                icon: const Icon(Icons.copy_all_outlined, size: 17),
                label: const Text('再次复制授权链接'),
              ),
            ),
            Text(
              '粘贴授权后的链接',
              style: TextStyle(
                color: context.appText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _callbackController,
              minLines: 2,
              maxLines: 4,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText:
                    'https://tcsisu.educationgroup.cn/robots.txt?code=...',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _complete,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_busy ? '正在验证并同步' : '完成验证并同步'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  if (value.millisecondsSinceEpoch <= 0) {
    return '--';
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
