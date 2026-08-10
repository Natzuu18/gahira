/// Thrown when a remote/API call fails (bad response, timeout, etc.)
class ServerException implements Exception {
  final String message;
  ServerException([this.message = 'A server error occurred']);
}

/// Thrown when a local cache/storage operation fails
class CacheException implements Exception {
  final String message;
  CacheException([this.message = 'A cache error occurred']);
}

/// Thrown when there's no internet connection
class NetworkException implements Exception {
  final String message;
  NetworkException([this.message = 'No internet connection']);
}

/// Thrown on authentication failures — invalid credentials, expired token, etc.
class AuthException implements Exception {
  final String message;
  AuthException([this.message = 'Authentication failed']);
}

/// Thrown when input validation fails before hitting the server
class ValidationException implements Exception {
  final String message;
  ValidationException([this.message = 'Invalid input']);
}