import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/instagram_account.dart';

class FollowResult {
  final bool isSuccess;
  final String message;
  final bool isRateLimited;
  final bool isChallengeRequired;

  FollowResult({
    required this.isSuccess,
    required this.message,
    this.isRateLimited = false,
    this.isChallengeRequired = false,
  });
}

class InstagramApiService {
  static const String _igAppId = '936619743392459';

  Map<String, String> _buildHeaders(InstagramAccount account) {
    return {
      'User-Agent': account.userAgent.isNotEmpty
          ? account.userAgent
          : 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      'Cookie': account.cookieHeader,
      'X-CSRFToken': account.csrfToken ?? '',
      'X-IG-App-ID': _igAppId,
      'X-Requested-With': 'XMLHttpRequest',
      'Referer': 'https://www.instagram.com/',
      'Accept': '*/*',
    };
  }

  /// Converts a username to numeric Instagram User ID
  Future<String?> getUserIdFromUsername(
      String username, InstagramAccount caller) async {
    final cleanUsername = username.trim().replaceAll('@', '');
    final url = Uri.parse(
        'https://www.instagram.com/api/v1/users/web_profile_info/?username=$cleanUsername');

    try {
      final response = await http.get(url, headers: _buildHeaders(caller));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['data']?['user'];
        if (user != null && user['id'] != null) {
          return user['id'].toString();
        }
      }
    } catch (e) {
      // Fallback or error
    }
    return null;
  }

  /// Sends a follow request to targetUserId using caller account's session
  Future<FollowResult> followUser(
      String targetUserId, InstagramAccount caller) async {
    final url = Uri.parse(
        'https://www.instagram.com/api/v1/friendships/create/$targetUserId/');

    try {
      final headers = _buildHeaders(caller);
      headers['Content-Type'] = 'application/x-www-form-urlencoded';

      final response = await http.post(
        url,
        headers: headers,
        body: {'user_id': targetUserId},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'ok') {
          final resultStr = data['result'] ?? 'following';
          return FollowResult(
            isSuccess: true,
            message: 'با موفقیت فالو شد ($resultStr)',
          );
        }
      }

      if (response.statusCode == 429 || response.body.contains('feedback_required')) {
        return FollowResult(
          isSuccess: false,
          message: 'محدودیت فالو اینستاگرام (Rate Limit / Action Block)',
          isRateLimited: true,
        );
      }

      if (response.statusCode == 400 && response.body.contains('challenge_required')) {
        return FollowResult(
          isSuccess: false,
          message: 'نیاز به تایید امنیتی اینستاگرام (Challenge Required)',
          isChallengeRequired: true,
        );
      }

      return FollowResult(
        isSuccess: false,
        message: 'خطا در فالو (کد وضعیت: ${response.statusCode})',
      );
    } catch (e) {
      return FollowResult(
        isSuccess: false,
        message: 'خطای ارتباط با شبکه: $e',
      );
    }
  }

  /// Checks if account session is still valid
  Future<bool> checkSessionHealth(InstagramAccount account) async {
    final url = Uri.parse('https://www.instagram.com/api/v1/accounts/current_user/');
    try {
      final response = await http.get(url, headers: _buildHeaders(account));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'ok';
      }
    } catch (_) {}
    return false;
  }
}
