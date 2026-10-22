import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../app_theme.dart';
import '../app_palette.dart';
import '../services/jw_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  Uint8List? _captchaBytes;
  bool _loadingCaptcha = true;
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _usernameController.text = context.read<AppState>().username ?? '';
    _loadCaptcha(resetSession: true);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha({bool resetSession = false}) async {
    setState(() {
      _loadingCaptcha = true;
      _captchaController.clear();
    });
    try {
      final bytes = await context.read<AppState>().loadCaptcha(
        resetSession: resetSession,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _captchaBytes = bytes;
        _loadingCaptcha = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingCaptcha = false;
        _message = _friendlyError(error);
      });
    }
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final captcha = _captchaController.text.trim();
    if (username.isEmpty || password.isEmpty || captcha.isEmpty) {
      setState(() => _message = '请完整填写学号、密码和验证码');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });
    try {
      await context.read<AppState>().login(
        username: username,
        password: password,
        captcha: captcha,
      );
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.pop(context);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _message = _friendlyError(error);
      });
      await _loadCaptcha();
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final background = context.appTheme.isDark ? Colors.black : primary;
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 34, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (Navigator.of(context).canPop()) ...[
                    IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '重外小助手',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '重外院',
                        style: TextStyle(
                          color: Color(0xFFD8E9FF),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '登录教务系统',
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '使用学校强智教务账号登录',
                      style: TextStyle(color: context.appMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _usernameController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '学号',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _captchaController,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            decoration: const InputDecoration(
                              labelText: '验证码',
                              prefixIcon: Icon(Icons.verified_user_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _loadingCaptcha ? null : () => _loadCaptcha(),
                          child: Container(
                            width: 118,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _loadingCaptcha
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _captchaBytes == null
                                ? Icon(Icons.refresh, color: primary)
                                : Image.memory(
                                    _captchaBytes!,
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '看不清验证码？点击图片刷新',
                      style: TextStyle(color: context.appMuted, fontSize: 11),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            color: Color(0xFFAA2424),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Text('登录'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  '账号信息仅用于登录学校教务系统',
                  style: TextStyle(color: Color(0xFFD8E9FF), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _friendlyError(Object error) {
    if (error is LoginException) {
      return error.message;
    }
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Connection')) {
      return '网络连接失败，请检查网络后重试';
    }
    final statusMatch = RegExp(r'status code of (\d{3})').firstMatch(text);
    if (statusMatch != null) {
      return '登录请求失败，服务器返回 ${statusMatch.group(1)}';
    }
    return text.replaceFirst('Exception: ', '');
  }
}
