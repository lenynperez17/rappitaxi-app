import 'package:dio/dio.dart';
import 'token_service.dart';

class AuthInterceptor extends Interceptor {
  final TokenService _tokenService;
  
  AuthInterceptor() : _tokenService = TokenService();
  
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Excluir rutas que no necesitan autenticación
    final excludedPaths = [
      '/auth/login',
      '/auth/register',
      '/auth/forgot-password',
      '/auth/verify-otp',
    ];
    
    final isExcluded = excludedPaths.any(
      (path) => options.path.contains(path),
    );
    
    if (!isExcluded) {
      final token = await _tokenService.getAccessToken();
      
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    
    handler.next(options);
  }
  
  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      // Token expirado o inválido
      final refreshToken = await _tokenService.getRefreshToken();
      
      if (refreshToken != null) {
        try {
          // Intentar refrescar el token
          final dio = Dio(BaseOptions(
            baseUrl: err.requestOptions.baseUrl,
            connectTimeout: err.requestOptions.connectTimeout,
            receiveTimeout: err.requestOptions.receiveTimeout,
          ));
          
          final response = await dio.post(
            '/auth/refresh',
            data: {'refreshToken': refreshToken},
          );
          
          final newAccessToken = response.data['accessToken'];
          final newRefreshToken = response.data['refreshToken'];
          
          // Guardar nuevos tokens
          await _tokenService.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          
          // Reintentar la solicitud original
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';
          
          final cloneReq = await dio.fetch(err.requestOptions);
          return handler.resolve(cloneReq);
        } catch (e) {
          // Error al refrescar token, limpiar tokens
          await _tokenService.clearTokens();
          handler.next(err);
        }
      } else {
        // No hay refresh token, limpiar tokens
        await _tokenService.clearTokens();
        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }
}