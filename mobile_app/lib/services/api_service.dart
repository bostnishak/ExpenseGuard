import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Merkezi API iletişim katmanı.
/// Tüm HTTP istekleri buradan geçer; token yönetimi, hata işleme ve
/// otomatik refresh token burada gerçekleşir.
/// API offline ise demo mod ile çalışır.
class ApiService {
  // Android emülatör için 10.0.2.2, gerçek cihaz için sunucu IP'si
  static const String _baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  static const String _tokenKey        = 'eg_token';
  static const String _refreshTokenKey = 'eg_refresh_token';
  static const String _tenantDomainKey = 'eg_tenant_domain';
  static const String _demoModeKey     = 'eg_demo_mode';
  static const String _demoRoleKey     = 'eg_demo_role';
  static const String _demoEmailKey    = 'eg_demo_email';

  // ── Token Yönetimi ──────────────────────────────────────────

  static const _storage = FlutterSecureStorage();

  static Future<String?> getToken() async =>
      await _storage.read(key: _tokenKey);

  static Future<String?> getRefreshToken() async =>
      await _storage.read(key: _refreshTokenKey);

  static Future<String?> getTenantDomain() async =>
      await _storage.read(key: _tenantDomainKey) ?? 'demo.com';

  static Future<bool> isDemoMode() async {
    final val = await _storage.read(key: _demoModeKey);
    return val == 'true';
  }

  static Future<void> saveTokens({
    required String token,
    required String refreshToken,
    required String tenantDomain,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _tenantDomainKey, value: tenantDomain);
    await _storage.write(key: _demoModeKey, value: 'false');
  }

  /// Demo oturum kaydet (API offline fallback)
  static Future<void> saveDemoSession({
    required String email,
    required String role,
    required String domain,
  }) async {
    await _storage.write(key: _demoModeKey, value: 'true');
    await _storage.write(key: _demoEmailKey, value: email);
    await _storage.write(key: _demoRoleKey, value: role);
    await _storage.write(key: _tenantDomainKey, value: domain);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _demoModeKey);
    await _storage.delete(key: _demoRoleKey);
    await _storage.delete(key: _demoEmailKey);
  }

  // ── Demo Veri ─────────────────────────────────────────────────

  static final List<Map<String, dynamic>> _demoReceipts = [
    {'id': 'demo-r1', 'vendorName': 'Migros Ataşehir', 'category': 'food', 'amount': 485.50, 'receiptDate': '2025-04-15', 'status': 'Approved', 'riskLevel': 'Low', 'fraudScore': 12},
    {'id': 'demo-r2', 'vendorName': 'Shell Petrol - Kadıköy', 'category': 'fuel', 'amount': 1250.00, 'receiptDate': '2025-04-14', 'status': 'Approved', 'riskLevel': 'Low', 'fraudScore': 8},
    {'id': 'demo-r3', 'vendorName': 'Hilton Istanbul Bosphorus', 'category': 'accommodation', 'amount': 4800.00, 'receiptDate': '2025-04-13', 'status': 'Flagged', 'riskLevel': 'High', 'fraudScore': 78},
    {'id': 'demo-r4', 'vendorName': 'Uber Türkiye', 'category': 'transport', 'amount': 185.75, 'receiptDate': '2025-04-12', 'status': 'Approved', 'riskLevel': 'Low', 'fraudScore': 22},
    {'id': 'demo-r5', 'vendorName': 'Nusr-Et Steakhouse', 'category': 'food', 'amount': 8750.00, 'receiptDate': '2025-04-11', 'status': 'Rejected', 'riskLevel': 'High', 'fraudScore': 92},
    {'id': 'demo-r6', 'vendorName': 'Teknosa Levent', 'category': 'office', 'amount': 3200.00, 'receiptDate': '2025-04-10', 'status': 'Approved', 'riskLevel': 'Medium', 'fraudScore': 35},
    {'id': 'demo-r7', 'vendorName': 'BiTaksi', 'category': 'transport', 'amount': 92.50, 'receiptDate': '2025-04-09', 'status': 'Approved', 'riskLevel': 'Low', 'fraudScore': 5},
    {'id': 'demo-r8', 'vendorName': 'Starbucks Maslak', 'category': 'food', 'amount': 145.00, 'receiptDate': '2025-04-08', 'status': 'Pending', 'riskLevel': 'Low', 'fraudScore': null},
    {'id': 'demo-r9', 'vendorName': 'THY - Ankara Uçuş', 'category': 'transport', 'amount': 2150.00, 'receiptDate': '2025-04-07', 'status': 'Approved', 'riskLevel': 'Low', 'fraudScore': 15},
    {'id': 'demo-r10', 'vendorName': 'Gece Kulübü XYZ', 'category': 'entertainment', 'amount': 6500.00, 'receiptDate': '2025-04-06', 'status': 'Flagged', 'riskLevel': 'High', 'fraudScore': 85},
  ];

  static ApiResponse _demoFallback(String path) {
    if (path.contains('/api/receipts/my') || path.contains('/api/receipts/high-risk')) {
      final items = path.contains('high-risk')
          ? _demoReceipts.where((r) => (r['fraudScore'] ?? 0) >= 60).toList()
          : _demoReceipts;
      return ApiResponse(statusCode: 200, data: {'items': items});
    }
    if (path.contains('/api/auth/me')) {
      return const ApiResponse(statusCode: 200, data: {
        'email': 'demo@expenseguard.com',
        'fullName': 'Demo Kullanıcı',
        'role': 'admin',
        'tenantId': '11111111-1111-1111-1111-111111111111',
        'departmentId': '21111111-1111-1111-1111-111111111111',
      });
    }
    return const ApiResponse(statusCode: 200, data: {'result': []});
  }

  // ── HTTP Helpers ────────────────────────────────────────────

  static Future<Map<String, String>> _buildHeaders({bool requiresAuth = true}) async {
    final domain = await getTenantDomain();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Tenant-Domain': domain ?? 'demo.com',
    };
    if (requiresAuth) {
      final token = await getToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// GET isteği — demo mod + otomatik token refresh desteği
  static Future<ApiResponse> get(String path) async {
    if (await isDemoMode()) return _demoFallback(path);

    final headers = await _buildHeaders();
    final response = await http.get(Uri.parse('$_baseUrl$path'), headers: headers);

    if (response.statusCode == 401) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _buildHeaders();
        final retryResponse = await http.get(Uri.parse('$_baseUrl$path'), headers: newHeaders);
        return ApiResponse.fromHttp(retryResponse);
      }
      return const ApiResponse(statusCode: 401, data: null, error: 'Oturum süresi doldu');
    }
    return ApiResponse.fromHttp(response);
  }

  /// POST isteği
  static Future<ApiResponse> post(
    String path,
    Map<String, dynamic> body, {
    bool requiresAuth = true,
  }) async {
    if (await isDemoMode()) {
      return const ApiResponse(statusCode: 200, data: {'success': true});
    }

    final headers = await _buildHeaders(requiresAuth: requiresAuth);
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401 && requiresAuth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        final newHeaders = await _buildHeaders();
        final retryResponse = await http.post(
          Uri.parse('$_baseUrl$path'), headers: newHeaders, body: jsonEncode(body),
        );
        return ApiResponse.fromHttp(retryResponse);
      }
      return const ApiResponse(statusCode: 401, data: null, error: 'Oturum süresi doldu');
    }
    return ApiResponse.fromHttp(response);
  }

  /// Multipart POST — fotoğraf yüklemek için
  static Future<ApiResponse> postMultipart(
    String path,
    String filePath,
    Map<String, String> fields,
  ) async {
    if (await isDemoMode()) {
      return const ApiResponse(statusCode: 200, data: {'success': true, 'message': 'Demo modda yüklendi'});
    }

    final token  = await getToken();
    final domain = await getTenantDomain();
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'));
    request.headers.addAll({
      'Authorization': 'Bearer ${token ?? ''}',
      'X-Tenant-Domain': domain ?? 'demo.com',
    });
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    request.fields.addAll(fields);

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return ApiResponse.fromHttp(response);
  }

  // ── Refresh Token ───────────────────────────────────────────

  static Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final domain = await getTenantDomain();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/refresh'),
        headers: {'Content-Type': 'application/json', 'X-Tenant-Domain': domain ?? 'demo.com'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveTokens(token: data['token'], refreshToken: data['refreshToken'], tenantDomain: domain ?? 'demo.com');
        return true;
      }
      await clearTokens();
      return false;
    } catch (_) {
      return false;
    }
  }

  // ── Auth Endpoints ──────────────────────────────────────────

  static Future<ApiResponse> login(String email, String password, String domain) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json', 'X-Tenant-Domain': domain},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 3));
      
      final result = ApiResponse.fromHttp(response);
      if (result.statusCode == 200 && result.data != null) {
        await saveTokens(
          token: result.data!['token'],
          refreshToken: result.data!['refreshToken'],
          tenantDomain: domain,
        );
      }
      return result;
    } catch (e) {
      // API Offline veya timeout durumunda hata fırlat ki LoginScreen'deki catch (demo mode) çalışsın.
      throw Exception('Sunucu bağlantısı kurulamadı: $e');
    }
  }

  static Future<void> logout() async {
    if (!await isDemoMode()) {
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        try { await post('/api/auth/logout', {'refreshToken': refreshToken}); } catch (_) {}
      }
    }
    await clearTokens();
  }

  static Future<void> logoutAll() async {
    if (!await isDemoMode()) {
      try { await post('/api/auth/logout-all', {}); } catch (_) {}
    }
    await clearTokens();
  }

  // ── Receipt Endpoints ───────────────────────────────────────

  static Future<ApiResponse> getMyReceipts({int page = 1, int pageSize = 20}) =>
      get('/api/receipts/my?page=$page&pageSize=$pageSize');

  static Future<ApiResponse> getHighRiskReceipts({int minScore = 60}) =>
      get('/api/receipts/high-risk?minScore=$minScore');

  static Future<ApiResponse> approveReceipt(String id) =>
      post('/api/receipts/$id/approve', {});

  static Future<ApiResponse> rejectReceipt(String id, String reason) =>
      post('/api/receipts/$id/reject', {'reason': reason});

  // ── Budget Endpoints ────────────────────────────────────────

  static Future<ApiResponse> getBudgetStatus(String deptId, int year, int month) =>
      get('/api/budgets/$deptId/$year/$month');

  // ── Auth Info ───────────────────────────────────────────────

  static Future<ApiResponse> getMe() => get('/api/auth/me');
}

// ── Response Wrapper ─────────────────────────────────────────
class ApiResponse {
  final int statusCode;
  final Map<String, dynamic>? data;
  final String? error;

  const ApiResponse({
    required this.statusCode,
    required this.data,
    this.error,
  });

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  factory ApiResponse.fromHttp(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse(
          statusCode: response.statusCode,
          data: body is Map<String, dynamic> ? body : {'result': body},
        );
      } else {
        final errMsg = body is Map ? (body['error'] ?? 'Hata oluştu') : 'Hata oluştu';
        return ApiResponse(statusCode: response.statusCode, data: null, error: errMsg.toString());
      }
    } catch (_) {
      return ApiResponse(statusCode: response.statusCode, data: null, error: 'Sunucu yanıtı işlenemedi');
    }
  }
}
