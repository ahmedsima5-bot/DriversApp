// services/network_service.dart
class NetworkService {
  static Future<T> withRetry<T>(
      Future<T> Function() function, {
        int maxRetries = 3,
        Duration delay = const Duration(seconds: 2),
      }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await function();
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(delay * (i + 1));
      }
    }
    throw Exception('Max retries exceeded');
  }
}