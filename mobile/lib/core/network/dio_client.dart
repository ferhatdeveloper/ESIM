import 'package:dio/dio.dart';

import '../constants/api_constants.dart';
import '../errors/app_exception.dart';
import '../security/token_store.dart';

class DioClient {
  DioClient({
    required TokenStore tokenStore,
    required Future<bool> Function() onRefresh,
    required void Function() onSessionLost,
    String? baseUrl,
  }) : _tokenStore = tokenStore,
       _onRefresh = onRefresh,
       _onSessionLost = onSessionLost {
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.postgrestBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStore.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final isAuthCall = path.contains('/rpc/login') ||
              path.contains('/rpc/register') ||
              path.contains('/rpc/refresh_session');
          if (status == 401 && !isAuthCall && !_refreshing) {
            _refreshing = true;
            try {
              final ok = await _onRefresh();
              if (ok) {
                final token = await _tokenStore.readAccessToken();
                final req = error.requestOptions;
                req.headers['Authorization'] = 'Bearer $token';
                final clone = await dio.fetch(req);
                handler.resolve(clone);
                return;
              }
              _onSessionLost();
            } finally {
              _refreshing = false;
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStore _tokenStore;
  final Future<bool> Function() _onRefresh;
  final void Function() _onSessionLost;
  bool _refreshing = false;
  late final Dio dio;

  static AppException mapError(DioException error) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return const NetworkException();
    }
    final data = error.response?.data;
    String message = error.message ?? 'Request failed';
    if (data is Map && data['message'] is String) {
      message = data['message'] as String;
    } else if (data is String && data.isNotEmpty) {
      message = data;
    }
    if (error.response?.statusCode == 401) {
      return UnauthorizedException(message);
    }
    return AppException(message, statusCode: error.response?.statusCode);
  }
}
