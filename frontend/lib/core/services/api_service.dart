import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static int? globalNepaliYear;
  static int? globalNepaliMonth;

  ApiService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.accessTokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry the failed request
            final token = await _storage.read(key: AppConstants.accessTokenKey);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            try {
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await Dio().post(
        '${AppConstants.baseUrl}${AppConstants.tokenRefreshEndpoint}',
        data: {'refresh': refreshToken},
      );
      await _storage.write(
        key: AppConstants.accessTokenKey,
        value: response.data['access'],
      );
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    final params = queryParams != null ? Map<String, dynamic>.from(queryParams) : <String, dynamic>{};
    if (globalNepaliYear != null) params['nepali_year'] = globalNepaliYear;
    if (globalNepaliMonth != null) params['nepali_month'] = globalNepaliMonth;
    return _dio.get(path, queryParameters: params);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> patch(String path, {dynamic data}) {
    return _dio.patch(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> uploadFile(String path, FormData formData) {
    return _dio.post(path, data: formData);
  }

  /// Upload fields + optional file paths as multipart/form-data.
  Future<Response> postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, PlatformFile>? files,
  }) async {
    final formData = FormData.fromMap(fields);
    
    if (files != null) {
      for (final entry in files.entries) {
        final file = entry.value;
        if (file.bytes != null) {
          formData.files.add(MapEntry(
            entry.key,
            MultipartFile.fromBytes(file.bytes!, filename: file.name),
          ));
        } else if (file.path != null) {
          formData.files.add(MapEntry(
            entry.key,
            await MultipartFile.fromFile(file.path!, filename: file.name),
          ));
        }
      }
    }
    return _dio.post(path, data: formData);
  }

  static String getErrorMessage(dynamic e) {
    if (e is DioException) {
      if (e.response?.data != null) {
        if (e.response!.data is Map) {
          final data = e.response!.data as Map;
          if (data.containsKey('error')) return data['error'].toString();
          if (data.containsKey('detail')) return data['detail'].toString();
          if (data.containsKey('message')) return data['message'].toString();
          if (data.containsKey('non_field_errors')) {
            final nfe = data['non_field_errors'];
            return nfe is List ? nfe.join(', ') : nfe.toString();
          }

          final List<String> fieldErrors = [];
          void extractErrors(String prefix, dynamic value) {
            if (value is Map) {
              value.forEach((k, v) {
                final fieldName = prefix.isEmpty ? k.toString() : '$prefix $k';
                extractErrors(fieldName, v);
              });
            } else if (value is List) {
              final msgs = value.map((m) => m.toString()).join(' ');
              final cleanFieldName = prefix
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                  .join(' ');
              fieldErrors.add('$cleanFieldName: $msgs');
            } else if (value != null) {
              final cleanFieldName = prefix
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                  .join(' ');
              fieldErrors.add('$cleanFieldName: $value');
            }
          }

          data.forEach((k, v) => extractErrors(k.toString(), v));
          if (fieldErrors.isNotEmpty) {
            return fieldErrors.join(' • ');
          }
        } else if (e.response!.data is String) {
          final str = e.response!.data.toString();
          if (str.isNotEmpty && !str.startsWith('<!DOCTYPE')) {
            return str;
          }
        }
      }
      if (e.message != null && e.message!.isNotEmpty) {
        return e.message!;
      }
      return 'Network error or server unavailable';
    }
    return e.toString();
  }
}





