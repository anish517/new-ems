import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';
import '../services/api_service.dart';
import '../../features/auth/models/user_model.dart';

class AuthService {
  final ApiService _api = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Login with email + password, store JWT tokens
  Future<UserProfile> login(String email, String password) async {
    final response = await _api.post(AppConstants.tokenEndpoint, data: {
      'email': email,
      'password': password,
    });
    final access  = response.data['access']  as String;
    final refresh = response.data['refresh'] as String;

    await _storage.write(key: AppConstants.accessTokenKey,  value: access);
    await _storage.write(key: AppConstants.refreshTokenKey, value: refresh);

    return fetchMe();
  }

  /// Fetch current user profile + role
  Future<UserProfile> fetchMe() async {
    final response = await _api.get(AppConstants.meEndpoint);
    return UserProfile.fromJson(response.data);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.accessTokenKey);
    return token != null;
  }

  /// Logout — clear all stored tokens
  Future<void> logout() async {
    await _api.logout();
  }
}




