import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';

import '../models/course.dart';
import 'schedule_parser.dart';

class LoginException implements Exception {
  const LoginException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() => '登录状态已失效，请重新登录';
}

class JwClient {
  static const baseUrl = 'https://jw.educationgroup.cn';
  static const loginRoot = '/cqwywsxy';
  static const eduRoot = '/cqwywsxy_jsxsd';

  PersistCookieJar? _cookieJar;
  Dio? _dio;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    final supportDirectory = await getApplicationSupportDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${supportDirectory.path}/jw_cookies'),
      ignoreExpires: false,
    );
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        followRedirects: true,
        maxRedirects: 5,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/132.0.0.0 Mobile Safari/537.36',
          'Accept-Language': 'zh-CN,zh;q=0.9',
        },
      ),
    );
    _dio!.interceptors.add(CookieManager(_cookieJar!));
    _initialized = true;
  }

  Dio get _client {
    final client = _dio;
    if (client == null) {
      throw StateError('JwClient 尚未初始化');
    }
    return client;
  }

  PersistCookieJar get _jar {
    final jar = _cookieJar;
    if (jar == null) {
      throw StateError('CookieJar 尚未初始化');
    }
    return jar;
  }

  Future<Uint8List> loadCaptcha({bool resetSession = false}) async {
    await init();
    if (resetSession) {
      await _jar.deleteAll();
      await _client.get<String>(
        '$loginRoot/',
        options: Options(responseType: ResponseType.plain),
      );
    } else {
      await _client.get<String>(
        '$loginRoot/',
        options: Options(responseType: ResponseType.plain),
      );
    }
    final response = await _client.get<List<int>>(
      '$loginRoot/verifycode.servlet',
      queryParameters: {'t': DateTime.now().millisecondsSinceEpoch},
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const LoginException('验证码加载失败');
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> login({
    required String username,
    required String password,
    required String captcha,
  }) async {
    await init();
    final tokenResponse = await _client.post<String>(
      '$loginRoot/Logon.do?method=logon&flag=sess',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Referer': '$baseUrl$loginRoot/'},
      ),
    );
    final token = (tokenResponse.data ?? '').trim();
    final encoded = _encodeLoginData(username, password, token);

    var response = await _client.post<String>(
      '$loginRoot/Logon.do?method=logon',
      data: {
        'userAccount': '',
        'userPassword': '',
        'RANDOMCODE': captcha,
        'encoded': encoded,
      },
      options: Options(
        responseType: ResponseType.plain,
        contentType: Headers.formUrlEncodedContentType,
        headers: {'Referer': '$baseUrl$loginRoot/'},
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    // 强智登录接口通常返回 302 跳转到 /cqwywsxy_jsxsd/...
    // 部分 Dio 版本不会自动跟随带 Set-Cookie 的登录跳转，因此手动处理。
    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 300 && statusCode < 400) {
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        throw const LoginException('登录成功但服务器未返回跳转地址');
      }
      final target = Uri.parse(baseUrl).resolve(location).toString();
      response = await _followGetRedirects(
        target,
        referer: '$baseUrl$loginRoot/',
      );
    }

    final document = html_parser.parse(response.data ?? '');
    final title = (document.querySelector('title')?.text ?? '').trim();
    final hasPasswordInput = document.querySelector('#userPassword') != null;
    if (hasPasswordInput || title.contains('登录')) {
      final message = (document.querySelector('#showMsg')?.text ?? '').trim();
      throw LoginException(message.isEmpty ? '登录失败，请检查账号、密码和验证码' : message);
    }
  }

  Future<ScheduleSnapshot> fetchSchedule({String? term}) async {
    await init();
    final response = await _client.get<String>(
      '$eduRoot/xskb/xskb_list.do',
      queryParameters: {
        'Ves632DSdyV': 'NEW_XSD_PYGL',
        if (term != null && term.isNotEmpty) 'xnxq01id': term,
      },
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Referer': '$baseUrl$eduRoot/framework/xsMain.jsp'},
      ),
    );
    final html = response.data ?? '';
    final looksLikeLoginPage =
        html.contains('用户没有登录') ||
        html.contains('重新登录') ||
        html.contains('出错页面') ||
        html.contains('id="userPassword"') ||
        html.contains('Logon.do?method=logout') ||
        html.contains('正在转入统一认证') ||
        html.contains('/sso/auth');
    if (looksLikeLoginPage) {
      throw const SessionExpiredException();
    }
    if (!html.contains('id="kbtable"')) {
      throw const FormatException('未找到课表页面，学校系统可能已更新');
    }

    final parsed = ScheduleParser().parse(html);
    return ScheduleSnapshot(
      term: term?.isNotEmpty == true ? term! : parsed.term,
      terms: parsed.terms,
      courses: parsed.courses,
      fetchedAt: DateTime.now(),
    );
  }

  Future<void> clearSession() async {
    await init();
    await _jar.deleteAll();
  }

  Future<Response<String>> _followGetRedirects(
    String url, {
    String? referer,
  }) async {
    var currentUrl = url;
    for (var attempt = 0; attempt < 8; attempt++) {
      final response = await _client.get<String>(
        currentUrl,
        options: Options(
          responseType: ResponseType.plain,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
          headers: {'Referer': ?referer},
        ),
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 300 || statusCode >= 400) {
        return response;
      }
      final location = response.headers.value('location');
      if (location == null || location.isEmpty) {
        throw const LoginException('登录跳转缺少目标地址');
      }
      currentUrl = Uri.parse(currentUrl).resolve(location).toString();
    }
    throw const LoginException('登录跳转次数过多');
  }

  String _encodeLoginData(String username, String password, String token) {
    if (!token.contains('#')) {
      throw const LoginException('登录会话参数异常，请稍后重试');
    }
    final parts = token.split('#');
    var scode = parts.first;
    final sxh = parts[1];
    final raw = '$username%%%$password';
    final buffer = StringBuffer();

    for (var index = 0; index < raw.length; index++) {
      if (index >= 20) {
        buffer.write(raw.substring(index));
        break;
      }
      final prefixLength = int.parse(sxh[index]);
      buffer.write(raw[index]);
      buffer.write(scode.substring(0, prefixLength));
      scode = scode.substring(prefixLength);
    }
    return buffer.toString();
  }
}
