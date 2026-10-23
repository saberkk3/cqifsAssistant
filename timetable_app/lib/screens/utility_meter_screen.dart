import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_palette.dart';
import '../app_state.dart';
import '../app_theme.dart';
import '../services/utility_client.dart';
import '../widgets/utility_usage_sparkline.dart';

class UtilityMeterScreen extends StatefulWidget {
  const UtilityMeterScreen({
    super.key,
    required this.type,
    required this.snapshot,
    required this.client,
    required this.onSnapshotUpdated,
  });

  final UtilityMeterType type;
  final UtilitySnapshot snapshot;
  final UtilityClient client;
  final Future<void> Function(UtilitySnapshot) onSnapshotUpdated;

  @override
  State<UtilityMeterScreen> createState() => _UtilityMeterScreenState();
}

class _UtilityMeterScreenState extends State<UtilityMeterScreen> {
  late UtilitySnapshot _snapshot;
  bool _refreshing = false;
  String? _error;

  bool get _isElectricity => widget.type == UtilityMeterType.electricity;
  Color get _accent =>
      _isElectricity ? const Color(0xFFE69B16) : const Color(0xFF1687D9);

  @override
  void initState() {
    super.initState();
    _snapshot = widget.snapshot;
  }

  Future<void> _refresh() async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
      _error = null;
    });
    try {
      final snapshot = await widget.client.fetchSnapshot();
      await widget.onSnapshotUpdated(snapshot);
      if (mounted) {
        setState(() => _snapshot = snapshot);
      }
    } on UtilityAuthRequiredException catch (error) {
      if (mounted) {
        setState(() => _error = '${error.message}，请返回水电首页重新授权。');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _openRecharge() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => UtilityRechargeScreen(
          type: widget.type,
          snapshot: _snapshot,
          client: widget.client,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = _isElectricity
        ? _snapshot.electricityRecords
        : _snapshot.waterRecords;
    final remaining = _isElectricity
        ? _snapshot.electricityRemaining
        : _snapshot.waterRemaining;
    final balance = _isElectricity
        ? _snapshot.electricityBalance
        : _snapshot.waterBalance;
    final price = _isElectricity
        ? _snapshot.electricityPrice
        : _snapshot.waterPrice;
    final measuredAt = _isElectricity
        ? _snapshot.electricityMeasuredAt
        : _snapshot.waterMeasuredAt;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isElectricity ? '电表' : '水表'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appTheme.isDark
                    ? const Color(0xFF171717)
                    : _accent,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: context.appTheme.isDark
                      ? context.appBorder
                      : Colors.transparent,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _isElectricity
                              ? Icons.bolt_rounded
                              : Icons.water_drop_outlined,
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
                              _snapshot.roomName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_snapshot.buildingName} · 采集 ${_formatDateTime(measuredAt)}',
                              style: const TextStyle(
                                color: Color(0xFFE7F2FF),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Text(
                    _isElectricity ? '剩余电量' : '剩余水量',
                    style: const TextStyle(
                      color: Color(0xFFE4F0FF),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${remaining.toStringAsFixed(2)} ${widget.type.unit}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _NoticeCard(
                icon: Icons.info_outline,
                text: _error!,
                color: AppColors.warning,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                _MiniMetric(
                  label: '账户余额',
                  value: '¥${balance.toStringAsFixed(2)}',
                ),
                const SizedBox(width: 12),
                _MiniMetric(
                  label: '当前单价',
                  value: '¥${price.toStringAsFixed(2)}/${widget.type.unit}',
                ),
              ],
            ),
            const SizedBox(height: 18),
            _UsageTrendCard(
              type: widget.type,
              points: context.watch<AppState>().utilityHistory,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openRecharge,
              icon: Icon(
                _isElectricity
                    ? Icons.bolt_outlined
                    : Icons.water_drop_outlined,
              ),
              label: Text(_isElectricity ? '电费充值' : '水费充值'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  '充值记录',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '共 ${records.length} 条',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (records.isEmpty)
              _NoticeCard(
                icon: Icons.receipt_long_outlined,
                text: '暂无${widget.type.title}充值记录',
                color: Theme.of(context).colorScheme.primary,
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.appBorder),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < records.length; index++) ...[
                      _RecordRow(record: records[index], type: widget.type),
                      if (index != records.length - 1)
                        Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class UtilityRechargeScreen extends StatefulWidget {
  const UtilityRechargeScreen({
    super.key,
    required this.type,
    required this.snapshot,
    required this.client,
  });

  final UtilityMeterType type;
  final UtilitySnapshot snapshot;
  final UtilityClient client;

  @override
  State<UtilityRechargeScreen> createState() => _UtilityRechargeScreenState();
}

class _UtilityRechargeScreenState extends State<UtilityRechargeScreen> {
  static const _presets = [5.0, 10.0, 20.0, 50.0, 100.0, 200.0];

  final TextEditingController _amountController = TextEditingController();
  double? _amount;
  bool _busy = false;
  String? _error;

  bool get _isElectricity => widget.type == UtilityMeterType.electricity;
  double get _price => _isElectricity
      ? widget.snapshot.electricityPrice
      : widget.snapshot.waterPrice;
  double get _quantity => _price <= 0 ? 0 : (_amount ?? 0) / _price;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectAmount(double value) {
    setState(() {
      _amount = value;
      _amountController.text = value.toStringAsFixed(2);
      _error = null;
    });
  }

  void _onAmountChanged(String value) {
    setState(() => _amount = double.tryParse(value));
  }

  Future<void> _submit() async {
    final amount = _amount ?? 0;
    if (amount < 1 || amount > 10000) {
      setState(() => _error = '请输入 1 至 10000 元之间的充值金额');
      return;
    }
    if (_price <= 0 || _quantity <= 0) {
      setState(() => _error = '当前单价异常，暂时无法创建充值订单');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('确认充值信息'),
        content: Text(
          '房间：${widget.snapshot.roomName}\n'
          '类型：${widget.type.title}\n'
          '金额：¥${amount.toStringAsFixed(2)}\n'
          '预计到账：${_quantity.toStringAsFixed(2)} ${widget.type.unit}\n\n'
          '点击继续后将创建学校官方充值订单，并在支付页完成付款。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认创建'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final paymentUrl = await widget.client.createRechargeOrder(
        type: widget.type,
        amount: amount,
        quantity: _quantity,
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => UtilityPaymentWebView(
            paymentUrl: paymentUrl,
            title: '${widget.type.title}充值',
          ),
        ),
      );
    } on UtilityAuthRequiredException catch (error) {
      if (mounted) {
        setState(() => _error = '${error.message}，请返回水电首页重新授权。');
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

  @override
  Widget build(BuildContext context) {
    final remaining = _isElectricity
        ? widget.snapshot.electricityRemaining
        : widget.snapshot.waterRemaining;
    return Scaffold(
      appBar: AppBar(title: Text(_isElectricity ? '电费充值' : '水费充值')),
      body: ListView(
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
                  widget.snapshot.roomName,
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '当前剩余 ${remaining.toStringAsFixed(2)} ${widget.type.unit}'
                  ' · 单价 ¥${_price.toStringAsFixed(2)}/${widget.type.unit}',
                  style: TextStyle(
                    color: context.appMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            '选择充值金额',
            style: TextStyle(
              color: context.appText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            childAspectRatio: 2.1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              for (final amount in _presets)
                _AmountButton(
                  amount: amount,
                  selected: _amount == amount,
                  onTap: () => _selectAmount(amount),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: _onAmountChanged,
            decoration: const InputDecoration(
              labelText: '自定义金额',
              prefixText: '¥ ',
              hintText: '请输入充值金额',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  _isElectricity
                      ? Icons.bolt_rounded
                      : Icons.water_drop_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '预计到账 ${_quantity.toStringAsFixed(2)} ${widget.type.unit}',
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _NoticeCard(
              icon: Icons.info_outline,
              text: _error!,
              color: AppColors.warning,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_balance_wallet_outlined),
            label: Text(_busy ? '正在创建订单' : '创建官方充值订单'),
          ),
          const SizedBox(height: 12),
          Text(
            '充值订单由学校二期水电平台生成。请核对房间和金额，'
            '支付页若无法在 App 内完成，可复制链接到微信继续付款。',
            style: TextStyle(
              color: context.appMuted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class UtilityPaymentWebView extends StatefulWidget {
  const UtilityPaymentWebView({
    super.key,
    required this.paymentUrl,
    required this.title,
  });

  final String paymentUrl;
  final String title;

  @override
  State<UtilityPaymentWebView> createState() => _UtilityPaymentWebViewState();
}

class _UtilityPaymentWebViewState extends State<UtilityPaymentWebView> {
  late final WebViewController _controller;
  int _progress = 0;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.paymentUrl;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() => _progress = progress);
            }
          },
          onPageStarted: (url) {
            if (mounted) {
              setState(() => _currentUrl = url);
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _currentUrl = url;
                _progress = 100;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  Future<void> _copyPaymentUrl() async {
    await Clipboard.setData(ClipboardData(text: _currentUrl));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('支付链接已复制，可发送到微信继续付款')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '复制支付链接',
            onPressed: _copyPaymentUrl,
            icon: const Icon(Icons.copy_all_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100)
            LinearProgressIndicator(
              value: _progress / 100,
              minHeight: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: context.appMuted, fontSize: 11),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: context.appText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.record, required this.type});

  final UtilityPaymentRecord record;
  final UtilityMeterType type;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: type == UtilityMeterType.electricity
                  ? const Color(0xFFFFF2DB)
                  : const Color(0xFFE6F3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              type == UtilityMeterType.electricity
                  ? Icons.bolt_rounded
                  : Icons.water_drop_outlined,
              color: type == UtilityMeterType.electricity
                  ? const Color(0xFFE69B16)
                  : const Color(0xFF1687D9),
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${type.title}充值 ¥${record.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.payTime} · '
                  '${record.quantity.toStringAsFixed(2)} ${type.unit}',
                  style: TextStyle(color: context.appMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountButton extends StatelessWidget {
  const _AmountButton({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final double amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : context.appCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primary : context.appBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            '${amount.toStringAsFixed(0)} 元',
            style: TextStyle(
              color: selected ? primary : context.appText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
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

class _UsageTrendCard extends StatelessWidget {
  const _UsageTrendCard({required this.type, required this.points});

  final UtilityMeterType type;
  final List<UtilityHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    final visible = points.length > 30
        ? points.sublist(points.length - 30)
        : points;
    if (visible.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appBorder),
        ),
        child: Row(
          children: [
            Icon(Icons.show_chart_rounded, color: context.appMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '刷新两次以上水电数据后，这里会显示用量趋势。',
                style: TextStyle(
                  color: context.appMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }
    final values = visible
        .map(
          (point) => type == UtilityMeterType.electricity
              ? point.electricityRemaining
              : point.waterRemaining,
        )
        .toList();
    final first = visible.first;
    final last = visible.last;
    final firstValue = type == UtilityMeterType.electricity
        ? first.electricityRemaining
        : first.waterRemaining;
    final lastValue = type == UtilityMeterType.electricity
        ? last.electricityRemaining
        : last.waterRemaining;
    final hours = last.recordedAt.difference(first.recordedAt).inMinutes / 60;
    final dailyUsage = hours > 0 && firstValue > lastValue
        ? (firstValue - lastValue) / (hours / 24)
        : 0.0;
    final daysLeft = dailyUsage > 0 ? lastValue / dailyUsage : null;
    final accent = type == UtilityMeterType.electricity
        ? const Color(0xFFE69B16)
        : const Color(0xFF1687D9);
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
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: accent, size: 22),
              const SizedBox(width: 8),
              Text(
                '${type.title}用量趋势',
                style: TextStyle(
                  color: context.appText,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (daysLeft != null)
                Text(
                  '预计可用 ${daysLeft.toStringAsFixed(1)} 天',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          UtilityUsageSparkline(
            values: values,
            color: accent,
            gridColor: context.appBorder,
            height: 112,
          ),
          const SizedBox(height: 8),
          Text(
            dailyUsage > 0
                ? '日均消耗约 ${dailyUsage.toStringAsFixed(2)} ${type.unit}'
                : '当前历史数据中还没有检测到持续消耗',
            style: TextStyle(color: context.appMuted, fontSize: 10),
          ),
        ],
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
