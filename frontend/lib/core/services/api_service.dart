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

  /// Returns the current access token from secure storage.
  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    final params = queryParams != null ? Map<String, dynamic>.from(queryParams) : <String, dynamic>{};
    if (globalNepaliYear != null) params['nepali_year'] = globalNepaliYear;
    if (globalNepaliMonth != null) params['nepali_month'] = globalNepaliMonth;
    return _dio.get(path, queryParameters: params);
  }

  /// Download binary file bytes (e.g. .xlsx exports and templates).
  Future<Response<List<int>>> getBytes(
    String path, {
    Map<String, dynamic>? queryParams,
  }) {
    return _dio.get<List<int>>(
      path,
      queryParameters: queryParams,
      options: Options(responseType: ResponseType.bytes),
    );
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

  Future<Response> delete(String path, {dynamic data}) {
    return _dio.delete(path, data: data);
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

  /// Update fields + optional files as multipart/form-data via PATCH.
  Future<Response> patchMultipart(
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
    return _dio.patch(path, data: formData);
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
      switch (e.type) {
        case DioExceptionType.connectionError:
          return 'No internet connection. Please check your Wi-Fi or mobile data and try again.';
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
          return 'Connection timed out. Please check your internet connection and try again.';
        case DioExceptionType.badCertificate:
          return 'Unable to establish a secure connection to the server.';
        case DioExceptionType.cancel:
          return 'Request was cancelled.';
        case DioExceptionType.badResponse:
          final code = e.response?.statusCode;
          if (code == 401) return 'Your session has expired. Please sign in again.';
          if (code == 403) return 'You do not have permission to perform this action.';
          if (code == 404) return 'The requested resource was not found.';
          if (code != null && code >= 500) {
            return 'Server error. Please try again in a moment.';
          }
          return 'Request failed. Please try again.';
        case DioExceptionType.unknown:
          return 'Unable to connect to the server. Please check your internet connection and try again.';
      }
    }

    final raw = e.toString().replaceFirst('Exception: ', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection failed') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('cannot be solved by the library') ||
        lower.contains('clientexception') ||
        lower.contains('xmlhttprequest') ||
        lower.contains('handshakeexception')) {
      return 'No internet connection. Please check your Wi-Fi or mobile data and try again.';
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'Connection timed out. Please check your internet connection and try again.';
    }
    return raw.isNotEmpty ? raw : 'Something went wrong. Please try again.';
  }
}





