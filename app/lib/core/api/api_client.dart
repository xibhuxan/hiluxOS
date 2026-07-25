import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/config.dart';

/// Thin wrapper around Dio pointing at the hiluxOS backend.
class ApiClient {
  ApiClient(this._dio);
  final Dio _dio;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.get<T>(path, queryParameters: query);

  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _dio.post<T>(path, data: data);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(String path, {Map<String, dynamic>? query}) =>
      _dio.delete<T>(path, queryParameters: query);
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.restBase,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));
  dio.interceptors.add(LogInterceptor(
    request: false,
    requestHeader: false,
    responseHeader: false,
    responseBody: false,
    error: true,
  ));
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));