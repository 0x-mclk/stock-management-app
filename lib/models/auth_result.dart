class AuthResult {
  final bool success;
  final String? message;
  final String? userId;
  final Map<String, dynamic>? data;

  AuthResult({
    required this.success,
    this.message,
    this.userId,
    this.data,
  });

  factory AuthResult.success(
      {String? message, String? userId, Map<String, dynamic>? data}) {
    return AuthResult(
      success: true,
      message: message,
      userId: userId,
      data: data,
    );
  }

  factory AuthResult.failure(String message) {
    return AuthResult(
      success: false,
      message: message,
    );
  }
}




