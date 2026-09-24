import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

class ApiClient {
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: kApiBaseUrl,
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 60),
                headers: {'Content-Type': 'application/json'},
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  static const _tokenKey = 'jarvis_access_token';

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) => _storage.write(key: _tokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: _tokenKey);

  Future<String?> readToken() => _storage.read(key: _tokenKey);

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _dio.post(
      '/auth/register',
      data: {'email': email, 'password': password, 'name': name},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/auth/me');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> sendChat({
    required String message,
    int? conversationId,
  }) async {
    final res = await _dio.post(
      '/chat',
      data: {
        'message': message,
        if (conversationId != null) 'conversation_id': conversationId,
      },
    );
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> listConversations() async {
    final res = await _dio.get('/chat/conversations');
    return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> getConversation(int id) async {
    final res = await _dio.get('/chat/conversations/$id');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> trainingStats() async {
    final res = await _dio.get('/training/stats');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> listTrainingExamples() async {
    final res = await _dio.get('/training/examples');
    return (res.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createTrainingExample(List<Map<String, String>> messages) async {
    final res = await _dio.post('/training/examples', data: {'messages': messages});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> deleteTrainingExample(int id) async {
    await _dio.delete('/training/examples/$id');
  }

  /// rating: 1 good, -1 bad, 0 clear. [correction] = what Jarvis should have said.
  Future<void> sendFeedback({
    required int messageId,
    required int rating,
    String? correction,
  }) async {
    await _dio.post(
      '/chat/messages/$messageId/feedback',
      data: {
        'rating': rating,
        if (correction != null && correction.trim().isNotEmpty) 'correction': correction.trim(),
      },
    );
  }
}
