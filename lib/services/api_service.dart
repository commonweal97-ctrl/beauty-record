// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

class ApiService {
  static const String baseUrl = 'https://xn--80ane1al0e.xn--80abvyjk6cts.xn--p1ai';
  static String? _cookies;

  static Future<void> _loadCookies() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_cookies');
    final savedToken = prefs.getString('remember_token');
    
    if (raw != null && raw.isNotEmpty) {
      _cookies = raw;
    }
    
    if (savedToken != null && savedToken.isNotEmpty) {
      if (_cookies == null || !_cookies!.contains('remember_token=')) {
        _cookies = '${_cookies != null ? '$_cookies; ' : ''}remember_token=$savedToken';
      }
    }
  }

  static Future<void> init() async {
    await _loadCookies();
    try {
      await get('/api/auth/check-session');
    } catch (e) {
      AppLogger.debug('api_service: caught error: $e');
    }
  }

  static Future<void> clearSession() async {
    _cookies = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_cookies');
    await prefs.remove('remember_token');
  }

  static Future<void> _persistCookies() async {
    // Проверяем, что _cookies не null
    final cookies = _cookies;
    if (cookies == null || cookies.isEmpty) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_cookies', cookies);
      
      for (final cookie in cookies.split('; ')) {
        if (cookie.startsWith('remember_token=')) {
          await prefs.setString('remember_token', cookie.substring(15));
        }
      }
    } catch (e) {
      AppLogger.debug('Error persisting cookies: $e');
    }
  }

  static void _saveCookies(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie != null) {
      final newCookies = setCookie
          .split(',')
          .map((c) => c.trim().split(';').first.trim())
          .where((c) => c.contains('='))
          .join('; ');
      
      if (newCookies.isNotEmpty) {
        if (_cookies != null && _cookies!.isNotEmpty) {
          final existingMap = <String, String>{};
          for (final cookie in _cookies!.split('; ')) {
            final parts = cookie.split('=');
            if (parts.length >= 2) {
              existingMap[parts[0]] = parts.sublist(1).join('=');
            }
          }
          
          for (final cookie in newCookies.split('; ')) {
            final parts = cookie.split('=');
            if (parts.length >= 2) {
              existingMap[parts[0]] = parts.sublist(1).join('=');
            }
          }
          
          _cookies = existingMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
        } else {
          _cookies = newCookies;
        }
        _persistCookies();
      }
    }
  }

  static String? _getCsrfFromCookies() {
    final cookies = _cookies;
    if (cookies == null) return null;
    
    for (final cookie in cookies.split('; ')) {
      if (cookie.startsWith('csrf_token=')) {
        return cookie.substring('csrf_token='.length);
      }
    }
    return null;
  }

  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    final cookies = _cookies;
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }
    
    final csrf = _getCsrfFromCookies();
    if (csrf != null) {
      headers['X-CSRF-Token'] = csrf;
    }
    
    return headers;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    if (_cookies == null) await _loadCookies();
    
    // Проверяем CSRF токен
    if (_getCsrfFromCookies() == null) {
      await get('/api/auth/check-session');
    }
    
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.post(uri, headers: _headers, body: jsonEncode(body));
    _saveCookies(response);
    
    if (response.body.isEmpty) {
      return {'success': false, 'data': []};
    }
    
    try {
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false, 'data': []};
    }
  }

  static Future<Map<String, dynamic>> get(String path, {bool forceRefresh = false}) async {
    if (_cookies == null) await _loadCookies();
    
    final uri = Uri.parse('$baseUrl$path');
    final response = await http.get(uri, headers: _headers);
    _saveCookies(response);
    
    if (response.body.isEmpty) {
      return {'success': false, 'data': []};
    }
    
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        return {'success': false, 'data': []};
      }
    } catch (e) {
      return {'success': false, 'data': []};
    }
  }

  // ==================== ЗАГРУЗКА ФАЙЛОВ ====================

  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required String filePath,
    required String fileName,
    required String fieldName,
    Map<String, String>? additionalFields,
  }) async {
    if (_cookies == null) await _loadCookies();
    
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    
    final cookies = _cookies;
    if (cookies != null && cookies.isNotEmpty) {
      request.headers['Cookie'] = cookies;
    }
    
    final csrf = _getCsrfFromCookies();
    if (csrf != null) {
      request.headers['X-CSRF-Token'] = csrf;
    }
    
    if (additionalFields != null) {
      additionalFields.forEach((key, value) {
        request.fields[key] = value;
      });
    }
    
    request.files.add(
      await http.MultipartFile.fromPath(fieldName, filePath, filename: fileName),
    );
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    _saveCookies(response);
    
    if (response.body.isEmpty) {
      return {'success': false};
    }
    
    try {
      return jsonDecode(response.body);
    } catch (e) {
      return {'success': false};
    }
  }

  // ==================== АВТОРИЗАЦИЯ ====================

  static Future<Map<String, dynamic>> checkUser(String identifier, String type) async {
    return _post('/api/auth/check', {'identifier': identifier, 'type': type});
  }

  static Future<Map<String, dynamic>> sendOtp(int userId, String identifier, String type) async {
    return _post('/api/auth/send-otp', {'user_id': userId, 'identifier': identifier, 'type': type});
  }

  static Future<Map<String, dynamic>> verifyOtp(int userId, String code) async {
    return _post('/api/auth/verify-otp', {'user_id': userId, 'otp_code': code, 'remember': true});
  }

  static Future<Map<String, dynamic>> register({
    required String phone,
    required String email,
    required String firstName,
    required String lastName,
    bool subscribe = true,
    bool termsAccepted = false,
  }) async {
    return _post('/api/auth/register', {
      'phone': phone,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'subscribe': subscribe,
      'terms_accepted': termsAccepted,
    });
  }

  static Future<Map<String, dynamic>> savePin(int userId, String pin) async {
    return _post('/api/auth/save-pin', {'user_id': userId, 'pin_code': pin});
  }

  static Future<Map<String, dynamic>> verifyPin(int userId, String pin) async {
    return _post('/api/auth/verify-pin', {'user_id': userId, 'pin_code': pin});
  }

  static Future<Map<String, dynamic>> deletePin() async {
    return _post('/api/quick-login/pin/delete', {});
  }

  static Future<Map<String, dynamic>> deleteBiometric() async {
    return _post('/api/biometric/unregister', {});
  }

  static Future<Map<String, dynamic>> logout() async {
    return _post('/api/auth/logout', {});
  }

  // ==================== ЗАПИСИ ====================

  static Future<Set<String>> getAvailableDates(int projectId, int employeeId, String serviceIds) async {
    final today = DateTime.now();
    final endDate = DateTime(today.year, today.month + 3, today.day);
    final params = {
      'project_id': projectId.toString(),
      'employee_id': employeeId.toString(),
      'start_date': DateFormat('yyyy-MM-dd').format(today),
      'end_date': DateFormat('yyyy-MM-dd').format(endDate),
      'service_ids': serviceIds,
    };
    final uri = Uri.parse('$baseUrl/api/booking/availability-summary').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);
    _saveCookies(response);
    final data = jsonDecode(response.body);
    if (data['success'] == true) {
      final dates = (data['data']['available_dates'] as List?) ?? [];
      return dates.map((d) => d['date'].toString()).toSet();
    }
    return {};
  }

  static Future<Map<String, dynamic>> createBooking({
    required int projectId,
    required String date,
    required String startTime,
    required List<int> serviceIds,
    required int employeeId,
    required String clientName,
    required String clientPhone,
    int? clientId,
    Map<int, int>? serviceMasters,
  }) async {
    final body = {
      'project_id': projectId,
      'date': date,
      'start_time': startTime,
      'services': serviceIds,
      'service_ids': serviceIds,
      'employee_id': employeeId,
    };
    
    if (serviceMasters != null && serviceMasters.isNotEmpty) {
      final serviceMastersStr = <String, int>{};
      serviceMasters.forEach((key, value) {
        serviceMastersStr[key.toString()] = value;
      });
      body['service_masters'] = serviceMastersStr;
    } else {
      body['service_masters'] = {serviceIds.first.toString(): employeeId};
    }
    
    if (clientId != null) {
      body['client_id'] = clientId;
    } else {
      body['client_name'] = clientName;
      body['client_phone'] = clientPhone;
    }
    
    return _post('/api/booking/create', body);
  }

  static Future<Map<String, dynamic>> rescheduleBooking({required int bookingId, required String date, required String time, String token = ''}) async {
    return _post('/api/booking/reschedule', {'booking_id': bookingId, 'date': date, 'time': time, 'token': token});
  }

  static Future<Map<String, dynamic>> updateBooking({
    required int bookingId, required int projectId,
    String? status, String? attendance, String? color, String? comment,
    int? breakAfter, bool? confirmedByClient,
    List<String>? reminders,
    String? reviewRequest,
    bool? confirmRequired,
    List<int>? serviceIds,
  }) async {
    final Map<String, dynamic> body = {
      'id': bookingId,
      'project_id': projectId,
    };
    if (status != null) body['status'] = status;
    if (attendance != null) body['attendance'] = attendance;
    if (color != null) body['color'] = color;
    if (comment != null) body['comment'] = comment;
    if (breakAfter != null) body['break_after'] = breakAfter;
    if (confirmedByClient != null) body['confirmed_by_client'] = confirmedByClient ? 1 : 0;
    if (reminders != null) body['reminders'] = reminders;
    if (reviewRequest != null) body['review_request'] = reviewRequest;
    if (confirmRequired != null) body['confirm_required'] = confirmRequired ? 1 : 0;
    if (serviceIds != null) body['service_ids'] = serviceIds;
    
    return _post('/api/booking/update', body);
  }

  static Future<Map<String, dynamic>> deleteBooking(int bookingId, int projectId) async {
    return _post('/api/booking/delete', {'id': bookingId, 'project_id': projectId});
  }

  static Future<Map<String, dynamic>> createOccupiedTime({
    required int projectId,
    required int employeeId,
    required String date,
    required String startTime,
    int duration = 60,
    bool allDay = false,
    String color = '#9e9e9e',
    String comment = '',
  }) async {
    return _post('/api/occupied-time/save', {
      'project_id': projectId,
      'employee_id': employeeId,
      'date': date,
      'start_time': startTime,
      'duration': duration,
      'all_day': allDay,
      'color': color,
      'comment': comment,
    });
  }

  static Future<Map<String, dynamic>> getOccupiedTime({required int projectId, required String date}) async {
    return get('/api/occupied-time/list?project_id=$projectId&date=$date');
  }

  static Future<Map<String, dynamic>> deleteOccupiedTime(int id) async {
    return _post('/api/occupied-time/delete', {'id': id});
  }

  // ==================== ПРОЕКТЫ И СЕТИ ====================

  static Future<Map<String, dynamic>> createProject({required String type, required String sphere, required String name, required String addressRaw}) async {
    return _post('/api/project/create', {'type': type, 'sphere': sphere, 'name': name, 'address_raw': addressRaw, 'terms': true, 'newsletter': true});
  }

  static Future<Map<String, dynamic>> createNetwork(String name, String slug) async {
    return _post('/api/network/save', {'name': name, 'slug': slug, 'project_ids': [], 'phone': '', 'social_links': '[]'});
  }

  static Future<Map<String, dynamic>> updateNetwork(String id, String name, String slug) async {
    return _post('/api/network/save', {'id': id, 'name': name, 'slug': slug, 'project_ids': [], 'phone': '', 'social_links': '[]'});
  }

  static Future<Map<String, dynamic>> deleteNetwork(int id) async {
    return _post('/api/network/delete', {'id': id});
  }
  
  static Future<Map<String, dynamic>> saveNetwork(Map<String, dynamic> body) async {
    return _post('/api/network/save', body);
  }

  // ==================== ПРОФИЛЬ ====================

  static Future<Map<String, dynamic>> updateProfile(String firstName, String lastName, String email, {String? newPassword, String? confirmPassword}) async {
    final body = {'first_name': firstName, 'last_name': lastName, 'email': email};
    if (newPassword != null) {
      body['new_password'] = newPassword;
      body['confirm_password'] = newPassword;
    }
    return _post('/api/profile', body);
  }

  // ==================== КЛИЕНТЫ ====================

  static Future<Map<String, dynamic>> saveClient(int projectId, String name, String phone, String email) async {
    return _post('/api/client/save', {'project_id': projectId, 'name': name, 'phone': phone, 'email': email});
  }

  static Future<Map<String, dynamic>> saveNotificationSettings({
    required int clientId,
    required int projectId,
    required Map<String, bool> settings,
  }) async {
    return _post('/api/client/notification-settings', {
      'client_id': clientId,
      'project_id': projectId,
      'settings': settings,
    });
  }

  // ==================== ЧАТ ====================

  static Future<Map<String, dynamic>> getChatList(int projectId, String type) async {
    return get('/api/chat/list?project_id=$projectId&type=$type');
  }

  static Future<Map<String, dynamic>> getChatMessages(int chatId) async {
    return get('/api/chat/messages?chat_id=$chatId');
  }

  static Future<Map<String, dynamic>> sendChatMessage(int chatId, String message, {String? fileUrl, String? fileType}) async {
    return _post('/api/chat/send', {
      'chat_id': chatId,
      'message': message,
      'file_url': ?fileUrl,
      'file_type': ?fileType,
    });
  }

  // ==================== DADATA ====================

  static Future<List<String>?> dadataSuggest(String query) async {
    try {
      final uri = Uri.parse('https://suggestions.dadata.ru/suggestions/api/4_1/rs/suggest/address');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token 3a827d10d5f52ae61c7332285e85411439c58c7b',
        },
        body: jsonEncode({
          'query': query,
          'count': 8,
          'from_bound': {'value': 'city'},
          'to_bound': {'value': 'settlement'},
          'locations': [{'country': 'Россия'}],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final seen = <String>{};
        final cities = <String>[];
        for (final s in data['suggestions'] ?? []) {
          final name = (s['data']?['city'] ?? s['data']?['settlement'] ?? '').toString();
          if (name.isNotEmpty && !seen.contains(name)) {
            seen.add(name);
            final region = (s['data']?['region_with_type'] ?? '').toString();
            cities.add(region.isNotEmpty && !region.contains(name) ? '$name, $region' : name);
          }
        }
        return cities;
      }
    } catch (e) {
      AppLogger.debug('api_service: caught error: $e');
    }
    return null;
  }

  static Future<List<String>> dadataAddress(String query) async {
    try {
      final uri = Uri.parse('https://suggestions.dadata.ru/suggestions/api/4_1/rs/suggest/address');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token c5ef8181057b91fbe37bbdedf3f635832e8f51ad',
        },
        body: jsonEncode({'query': query, 'count': 5}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['suggestions'] as List?)?.map((s) => s['value'].toString()).toList() ?? [];
      }
    } catch (_) {}
    return [];
  }

  // ==================== УТИЛИТЫ ====================

  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    return _post(path, body);
  }
}