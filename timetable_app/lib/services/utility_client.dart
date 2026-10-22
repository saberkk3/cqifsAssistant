import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class UtilityAuthRequiredException implements Exception {
  const UtilityAuthRequiredException([this.message = '水电登录已过期，请重新授权']);

  final String message;

  @override
  String toString() => message;
}

class UtilityException implements Exception {
  const UtilityException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum UtilityMeterType { water, electricity }

extension UtilityMeterTypeX on UtilityMeterType {
  String get payType => this == UtilityMeterType.electricity ? '1' : '3';

  String get title => this == UtilityMeterType.electricity ? '电表' : '水表';

  String get unit => this == UtilityMeterType.electricity ? '度' : '吨';
}

class UtilityPaymentRecord {
  const UtilityPaymentRecord({
    required this.amount,
    required this.quantity,
    required this.payTime,
    required this.orderId,
  });

  final double amount;
  final double quantity;
  final String payTime;
  final String orderId;

  factory UtilityPaymentRecord.fromJson(Map<String, dynamic> json) {
    return UtilityPaymentRecord(
      amount: _asDouble(json['payMoney']),
      quantity: _asDouble(json['payQuantity']),
      payTime: (json['payTime'] ?? '').toString(),
      orderId: (json['orderId'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'quantity': quantity,
    'payTime': payTime,
    'orderId': orderId,
  };
}

class UtilitySnapshot {
  const UtilitySnapshot({
    required this.realName,
    required this.studentNumber,
    required this.schoolName,
    required this.buildingName,
    required this.roomName,
    required this.waterRemaining,
    required this.waterBalance,
    required this.waterPrice,
    required this.waterMeasuredAt,
    required this.electricityRemaining,
    required this.electricityBalance,
    required this.electricityPrice,
    required this.electricityMeasuredAt,
    required this.waterRecords,
    required this.electricityRecords,
    required this.updatedAt,
  });

  final String realName;
  final String studentNumber;
  final String schoolName;
  final String buildingName;
  final String roomName;
  final double waterRemaining;
  final double waterBalance;
  final double waterPrice;
  final DateTime waterMeasuredAt;
  final double electricityRemaining;
  final double electricityBalance;
  final double electricityPrice;
  final DateTime electricityMeasuredAt;
  final List<UtilityPaymentRecord> waterRecords;
  final List<UtilityPaymentRecord> electricityRecords;
  final DateTime updatedAt;

  factory UtilitySnapshot.fromJson(Map<String, dynamic> json) {
    return UtilitySnapshot(
      realName: (json['realName'] ?? '').toString(),
      studentNumber: (json['studentNumber'] ?? '').toString(),
      schoolName: (json['schoolName'] ?? '').toString(),
      buildingName: (json['buildingName'] ?? '').toString(),
      roomName: (json['roomName'] ?? '').toString(),
      waterRemaining: _asDouble(json['waterRemaining']),
      waterBalance: _asDouble(json['waterBalance']),
      waterPrice: _asDouble(json['waterPrice']),
      waterMeasuredAt:
          DateTime.tryParse((json['waterMeasuredAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      electricityRemaining: _asDouble(json['electricityRemaining']),
      electricityBalance: _asDouble(json['electricityBalance']),
      electricityPrice: _asDouble(json['electricityPrice']),
      electricityMeasuredAt:
          DateTime.tryParse((json['electricityMeasuredAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      waterRecords: _recordsFromJson(json['waterRecords']),
      electricityRecords: _recordsFromJson(json['electricityRecords']),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'realName': realName,
    'studentNumber': studentNumber,
    'schoolName': schoolName,
    'buildingName': buildingName,
    'roomName': roomName,
    'waterRemaining': waterRemaining,
    'waterBalance': waterBalance,
    'waterPrice': waterPrice,
    'waterMeasuredAt': waterMeasuredAt.toIso8601String(),
    'electricityRemaining': electricityRemaining,
    'electricityBalance': electricityBalance,
    'electricityPrice': electricityPrice,
    'electricityMeasuredAt': electricityMeasuredAt.toIso8601String(),
    'waterRecords': waterRecords.map((item) => item.toJson()).toList(),
    'electricityRecords': electricityRecords
        .map((item) => item.toJson())
        .toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static List<UtilityPaymentRecord> _recordsFromJson(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => UtilityPaymentRecord.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }
}

class UtilityClient {
  static const _phase2Root = 'http://cg.cqifs.edu.cn/sdms-pay-weixin';
  static const _entryUrl = '$_phase2Root/service/weixin/waterEleServer';
  static const _openIdRedirect =
      'http://cg.cqifs.edu.cn/sdms-pay-weixin/service/weixin/getOpenId';
  static const _callbackUrl = 'https://tcsisu.educationgroup.cn/robots.txt';

  PersistCookieJar? _cookieJar;
  Dio? _dio;
  String? _pendingState;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }
    final supportDirectory = await getApplicationSupportDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${supportDirectory.path}/utility_cookies'),
      ignoreExpires: false,
    );
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        followRedirects: false,
        maxRedirects: 8,
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
      throw StateError('UtilityClient 尚未初始化');
    }
    return client;
  }

  Future<UtilitySnapshot> fetchSnapshot() async {
    await init();
    final user = await _fetchResult('service/find/userinfo');
    final water = await _fetchResult(
      'service/waterBalance?type=3&systemType=1',
    );
    final electricity = await _fetchResult('service/ammeterBalance?type=1');

    final roomId = user['roomId'];
    if (roomId == null || roomId.toString().isEmpty) {
      throw const UtilityException('当前账号尚未绑定宿舍房间');
    }

    final waterRecords = await _fetchRecords(
      'service/find/payPersonalRecord?payType=2&isRefund=2',
    );
    final electricityRecords = await _fetchRecords(
      'service/find/payPersonalRecord?payType=1&isRefund=2',
    );

    return UtilitySnapshot(
      realName: (user['realName'] ?? '').toString(),
      studentNumber: (user['studentNum'] ?? '').toString(),
      schoolName: (user['schoolName'] ?? '').toString(),
      buildingName: (user['loudongName'] ?? '').toString(),
      roomName: (user['roomName'] ?? '').toString(),
      waterRemaining: _asDouble(water['leftWater']),
      waterBalance: _asDouble(water['leftMoney']),
      waterPrice: _asDouble(water['coldWaterPrice']),
      waterMeasuredAt: _dateFromEpoch(water['monTime']),
      electricityRemaining: _asDouble(electricity['leftEle']),
      electricityBalance: _asDouble(electricity['leftMoney']),
      electricityPrice: _asDouble(electricity['elePrice']),
      electricityMeasuredAt: _dateFromEpoch(electricity['monTime']),
      waterRecords: waterRecords,
      electricityRecords: electricityRecords,
      updatedAt: DateTime.now(),
    );
  }

  Future<String> createRechargeOrder({
    required UtilityMeterType type,
    required double amount,
    required double quantity,
  }) async {
    await init();
    final response = await _client.post<dynamic>(
      '$_phase2Root/service/gzyy/pay/save',
      data: jsonEncode({
        'payType': type.payType,
        'payMoney': amount.toStringAsFixed(2),
        'payQuantity': quantity.toStringAsFixed(2),
      }),
      options: Options(
        followRedirects: false,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode == 301 || statusCode == 302) {
      throw const UtilityAuthRequiredException();
    }
    final data = _asMap(response.data);
    if (data == null) {
      throw const UtilityException('充值平台返回数据异常');
    }
    final apiStatus = data['statusCode'].toString();
    final message = (data['message'] ?? '').toString();
    if (apiStatus != '200') {
      throw UtilityException(message.isEmpty ? '创建充值订单失败' : message);
    }
    final orderToken = (data['resultObject'] ?? '').toString();
    if (orderToken.isEmpty) {
      throw UtilityException(message.isEmpty ? '充值平台未返回支付单号' : message);
    }
    return 'https://tcsisu.educationgroup.cn/ykt/api/pay/$orderToken';
  }

  Future<String> beginAuthorization() async {
    await init();
    _pendingState = null;

    final entry = await _client.get<String>(
      _entryUrl,
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final entryLocation = entry.headers.value('location');
    if (entryLocation == null || entryLocation.isEmpty) {
      throw const UtilityException('无法创建水电登录会话');
    }

    final authUrl = _resolve(entryUrl: _entryUrl, location: entryLocation);
    final authPage = await _client.get<String>(
      authUrl,
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final body = authPage.data ?? '';
    final match = RegExp(
      r'''url=([^"']+)''',
      caseSensitive: false,
    ).firstMatch(body);
    if (match == null) {
      throw const UtilityException('学校平台未返回微信授权地址');
    }
    final oauthUrl = match.group(1)!.replaceAll('&amp;', '&').trim();
    final state = Uri.tryParse(oauthUrl)?.queryParameters['state'];
    if (state == null || state.isEmpty) {
      throw const UtilityException('微信授权地址缺少 state 参数');
    }
    _pendingState = state;

    final captureUrl = Uri.https(
      'open.weixin.qq.com',
      '/connect/oauth2/authorize',
      {
        'appid': 'wxb400d71e690a3a94',
        'redirect_uri': _callbackUrl,
        'response_type': 'code',
        'scope': 'snsapi_base',
        'state': state,
        'connect_redirect': '1',
      },
    ).replace(fragment: 'wechat_redirect');
    return captureUrl.toString();
  }

  Future<UtilitySnapshot> completeAuthorization(String callbackUrl) async {
    await init();
    final callback = Uri.tryParse(callbackUrl.trim());
    if (callback == null) {
      throw const UtilityException('授权链接格式不正确');
    }
    final code = callback.queryParameters['code'];
    final state = callback.queryParameters['state'];
    if (code == null || code.isEmpty) {
      throw const UtilityException('链接中没有微信授权码 code');
    }
    if (_pendingState != null && state != _pendingState) {
      throw const UtilityException('授权状态已变化，请重新获取授权链接');
    }

    final exchangeUrl = Uri.https(
      'tcsisu.educationgroup.cn',
      '/wx/wxAuth/getAccessToken/13',
      {'redirect': _openIdRedirect, 'code': code, 'state': state ?? ''},
    );
    final exchange = await _client.get<String>(
      exchangeUrl.toString(),
      options: Options(
        followRedirects: false,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    final callbackLocation = exchange.headers.value('location');
    if (callbackLocation == null || callbackLocation.isEmpty) {
      throw const UtilityException('微信授权失败，请重新获取授权链接');
    }

    final loginUrl = _resolve(
      entryUrl: exchangeUrl.toString(),
      location: callbackLocation,
    );
    final login = await _client.get<String>(
      loginUrl,
      options: Options(
        followRedirects: true,
        maxRedirects: 10,
        responseType: ResponseType.plain,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if ((login.statusCode ?? 0) >= 400) {
      throw const UtilityException('水电平台登录失败');
    }
    _pendingState = null;
    return fetchSnapshot();
  }

  Future<Map<String, dynamic>> _fetchResult(String path) async {
    final response = await _client.get<dynamic>(
      '$_phase2Root/$path',
      options: Options(
        followRedirects: false,
        responseType: ResponseType.json,
        validateStatus: (status) => status != null && status < 500,
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );
    final statusCode = response.statusCode ?? 0;
    if (statusCode == 302 || statusCode == 301) {
      throw const UtilityAuthRequiredException();
    }
    final data = _asMap(response.data);
    if (data == null || data['statusCode'].toString() != '200') {
      throw UtilityException((data?['message'] ?? '水电接口返回异常').toString());
    }
    final result = _asMap(data['resultObject']);
    if (result == null) {
      throw const UtilityAuthRequiredException();
    }
    return result;
  }

  Future<List<UtilityPaymentRecord>> _fetchRecords(String path) async {
    try {
      final response = await _client.get<dynamic>(
        '$_phase2Root/$path',
        options: Options(
          followRedirects: false,
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'Accept': 'application/json',
            'X-Requested-With': 'XMLHttpRequest',
          },
        ),
      );
      final statusCode = response.statusCode ?? 0;
      if (statusCode == 301 || statusCode == 302) {
        throw const UtilityAuthRequiredException();
      }
      final data = _asMap(response.data);
      if (data == null || data['statusCode'].toString() != '200') {
        return const [];
      }
      final value = data['resultObject'];
      if (value is! List) {
        return const [];
      }
      return value
          .whereType<Map>()
          .map(
            (item) => UtilityPaymentRecord.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } on UtilityAuthRequiredException {
      rethrow;
    } catch (_) {
      return const [];
    }
  }

  String _resolve({required String entryUrl, required String location}) {
    return Uri.parse(entryUrl).resolve(location).toString();
  }

  static Map<String, dynamic>? _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry(key.toString(), value));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static DateTime _dateFromEpoch(Object? value) {
    final millis = int.tryParse(value?.toString() ?? '');
    if (millis == null || millis <= 0) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
