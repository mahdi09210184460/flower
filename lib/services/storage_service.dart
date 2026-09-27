import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/instagram_account.dart';

class StorageService {
  static const String _accountsKey = 'instagram_accounts';
  static const String _minDelayKey = 'automation_min_delay';
  static const String _maxDelayKey = 'automation_max_delay';

  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // Accounts persistence
  Future<List<InstagramAccount>> loadAccounts() async {
    final String? accountsJson = _prefs.getString(_accountsKey);
    if (accountsJson == null || accountsJson.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(accountsJson);
      return decoded.map((item) => InstagramAccount.fromJson(item)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAccounts(List<InstagramAccount> accounts) async {
    final String encoded = jsonEncode(accounts.map((a) => a.toJson()).toList());
    await _prefs.setString(_accountsKey, encoded);
  }

  // Automation Settings
  int get minDelaySeconds => _prefs.getInt(_minDelayKey) ?? 30;
  int get maxDelaySeconds => _prefs.getInt(_maxDelayKey) ?? 120;

  Future<void> saveDelays(int minSeconds, int maxSeconds) async {
    await _prefs.setInt(_minDelayKey, minSeconds);
    await _prefs.setInt(_maxDelayKey, maxSeconds);
  }
}
