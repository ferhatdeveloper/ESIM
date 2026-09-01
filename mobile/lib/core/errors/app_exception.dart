class AppException implements Exception {
  const AppException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Session expired']);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'Network unavailable']);
}

class EmptyException extends AppException {
  const EmptyException([super.message = 'No data']);
}
