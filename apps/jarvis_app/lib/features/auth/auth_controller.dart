import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._api);

  final ApiClient _api;

  bool loading = true;
  bool authenticated = false;
  String? name;
  String? email;
  String? error;

  Future<void> bootstrap() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final token = await _api.readToken();
      if (token == null || token.isEmpty) {
        authenticated = false;
      } else {
        final me = await _api.me();
        name = me['name'] as String?;
        email = me['email'] as String?;
        authenticated = true;
      }
    } catch (_) {
      await _api.clearToken();
      authenticated = false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final data = await _api.register(email: email, password: password, name: name);
      await _api.saveToken(data['access_token'] as String);
      this.name = data['name'] as String?;
      this.email = data['email'] as String?;
      authenticated = true;
      return true;
    } on DioException catch (e) {
      error = _dioMessage(e);
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    error = null;
    loading = true;
    notifyListeners();
    try {
      final data = await _api.login(email: email, password: password);
      await _api.saveToken(data['access_token'] as String);
      name = data['name'] as String?;
      this.email = data['email'] as String?;
      authenticated = true;
      return true;
    } on DioException catch (e) {
      error = _dioMessage(e);
      return false;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.clearToken();
    authenticated = false;
    name = null;
    email = null;
    notifyListeners();
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return e.message ?? 'Network error';
  }
}
