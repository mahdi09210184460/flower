import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/instagram_account.dart';
import 'instagram_api_service.dart';

class QueueProgress {
  final int totalTasks;
  final int completedTasks;
  final int failedTasks;
  final String currentActionMessage;
  final bool isRunning;

  QueueProgress({
    required this.totalTasks,
    required this.completedTasks,
    required this.failedTasks,
    required this.currentActionMessage,
    required this.isRunning,
  });

  double get percentage =>
      totalTasks > 0 ? (completedTasks + failedTasks) / totalTasks : 0.0;
}

class AutomationQueueService extends ChangeNotifier {
  final InstagramApiService _apiService;
  final Random _random = Random();

  bool _isRunning = false;
  bool _isPaused = false;
  int _totalTasks = 0;
  int _completedTasks = 0;
  int _failedTasks = 0;
  String _currentMessage = 'صف اتومیشن آماده است';

  final List<String> _logs = [];

  bool get isRunning => _isRunning;
  bool get isPaused => _isPaused;
  List<String> get logs => List.unmodifiable(_logs);

  QueueProgress get progress => QueueProgress(
        totalTasks: _totalTasks,
        completedTasks: _completedTasks,
        failedTasks: _failedTasks,
        currentActionMessage: _currentMessage,
        isRunning: _isRunning,
      );

  AutomationQueueService(this._apiService);

  void addLog(String message) {
    final timeStr = DateTime.now().toIso8601String().substring(11, 19);
    _logs.insert(0, '[$timeStr] $message');
    if (_logs.length > 200) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void stopQueue() {
    _isRunning = false;
    _isPaused = false;
    _currentMessage = 'صف متوقف شد';
    addLog('⛔ عملیات اتومیشن توسط کاربر متوقف شد.');
    notifyListeners();
  }

  void pauseQueue() {
    _isPaused = true;
    _currentMessage = 'صف موقتا متوقف شد (Paused)';
    addLog('⏸️ عملیات متوقف شد (پوز).');
    notifyListeners();
  }

  void resumeQueue() {
    _isPaused = false;
    addLog('▶️ ادامه عملیات...');
    notifyListeners();
  }

  /// Starts mutual follow automation between accounts
  Future<void> startMutualFollow({
    required List<InstagramAccount> accounts,
    required int minDelaySec,
    required int maxDelaySec,
    required Function(InstagramAccount updatedAccount) onAccountUpdated,
  }) async {
    if (_isRunning) return;

    final activeAccounts =
        accounts.where((a) => a.status == AccountStatus.active).toList();
    if (activeAccounts.length < 2) {
      addLog('⚠️ برای فالو متقابل حداقل ۲ اکانت فعال نیاز است.');
      return;
    }

    _isRunning = true;
    _isPaused = false;
    _completedTasks = 0;
    _failedTasks = 0;

    // Calculate total pairs
    _totalTasks = activeAccounts.length * (activeAccounts.length - 1);
    addLog('🚀 شروع فالو متقابل بین ${activeAccounts.length} اکانت (مجموع کل: $_totalTasks فالو)...');
    notifyListeners();

    for (int i = 0; i < activeAccounts.length; i++) {
      final caller = activeAccounts[i];

      for (int j = 0; j < activeAccounts.length; j++) {
        if (i == j) continue; // Don't follow self
        if (!_isRunning) break;

        while (_isPaused) {
          await Future.delayed(const Duration(seconds: 1));
          if (!_isRunning) break;
        }
        if (!_isRunning) break;

        final target = activeAccounts[j];
        _currentMessage = 'اکانت @${caller.username} در حال فالو کردن @${target.username}';
        notifyListeners();

        addLog('📌 @${caller.username} ➔ @${target.username} ...');

        final result = await _apiService.followUser(target.id, caller);

        if (result.isSuccess) {
          _completedTasks++;
          addLog('✅ @${caller.username} موفق شد @${target.username} را فالو کند.');
          onAccountUpdated(caller.copyWith(
            lastActionAt: DateTime.now(),
            followsCountToday: caller.followsCountToday + 1,
          ));
        } else {
          _failedTasks++;
          addLog('❌ خطا برای @${caller.username}: ${result.message}');

          if (result.isRateLimited) {
            onAccountUpdated(caller.copyWith(status: AccountStatus.rateLimited));
          } else if (result.isChallengeRequired) {
            onAccountUpdated(
                caller.copyWith(status: AccountStatus.challengeRequired));
          }
        }

        notifyListeners();

        // Random delay
        if (_completedTasks + _failedTasks < _totalTasks && _isRunning) {
          final delay = _random.nextInt(max(1, maxDelaySec - minDelaySec + 1)) +
              minDelaySec;
          _currentMessage = 'صبر به مدت $delay ثانیه جهت رعایت قوانین اینستاگرام...';
          addLog('⏳ تاخیر تصادفی: $delay ثانیه...');
          notifyListeners();

          await _waitWithCheck(delay);
        }
      }
    }

    _isRunning = false;
    _currentMessage = 'عملیات فالو متقابل به پایان رسید';
    addLog('🎉 پایان عملیات فالو متقابل.');
    notifyListeners();
  }

  /// Starts following a target user by all accounts
  Future<void> startTargetFollow({
    required List<InstagramAccount> accounts,
    required String targetUsername,
    required int minDelaySec,
    required int maxDelaySec,
    required Function(InstagramAccount updatedAccount) onAccountUpdated,
  }) async {
    if (_isRunning) return;

    final activeAccounts =
        accounts.where((a) => a.status == AccountStatus.active).toList();
    if (activeAccounts.isEmpty) {
      addLog('⚠️ هیچ اکانت فعالی برای فالو پیج هدف وجود ندارد.');
      return;
    }

    _isRunning = true;
    _isPaused = false;
    _completedTasks = 0;
    _failedTasks = 0;
    _totalTasks = activeAccounts.length;

    addLog('🔍 در حال دریافت آیدی عددی پیج هدف @$targetUsername...');
    _currentMessage = 'شناسایی آیدی پیج هدف @$targetUsername';
    notifyListeners();

    // Resolve target numeric user ID using the first active account
    final targetUserId = await _apiService.getUserIdFromUsername(
        targetUsername, activeAccounts.first);

    if (targetUserId == null) {
      addLog('❌ یافتن آیدی عددی برای @$targetUsername ناموفق بود.');
      _isRunning = false;
      _currentMessage = 'شناسایی آیدی هدف ناموفق بود';
      notifyListeners();
      return;
    }

    addLog('✅ آیدی پیج هدف یافت شد: $targetUserId. شروع فالو توسط ${activeAccounts.length} اکانت...');
    notifyListeners();

    for (int i = 0; i < activeAccounts.length; i++) {
      if (!_isRunning) break;

      while (_isPaused) {
        await Future.delayed(const Duration(seconds: 1));
        if (!_isRunning) break;
      }
      if (!_isRunning) break;

      final caller = activeAccounts[i];
      _currentMessage = 'اکانت @${caller.username} در حال فالو کردن @$targetUsername';
      notifyListeners();

      addLog('📌 [${i + 1}/${activeAccounts.length}] @${caller.username} ➔ @$targetUsername ...');

      final result = await _apiService.followUser(targetUserId, caller);

      if (result.isSuccess) {
        _completedTasks++;
        addLog('✅ @${caller.username} پیج هدف @$targetUsername را فالو کرد.');
        onAccountUpdated(caller.copyWith(
          lastActionAt: DateTime.now(),
          followsCountToday: caller.followsCountToday + 1,
        ));
      } else {
        _failedTasks++;
        addLog('❌ خطا برای @${caller.username}: ${result.message}');

        if (result.isRateLimited) {
          onAccountUpdated(caller.copyWith(status: AccountStatus.rateLimited));
        } else if (result.isChallengeRequired) {
          onAccountUpdated(
              caller.copyWith(status: AccountStatus.challengeRequired));
        }
      }

      notifyListeners();

      if (i < activeAccounts.length - 1 && _isRunning) {
        final delay = _random.nextInt(max(1, maxDelaySec - minDelaySec + 1)) +
            minDelaySec;
        _currentMessage = 'صبر به مدت $delay ثانیه...';
        addLog('⏳ تاخیر تصادفی: $delay ثانیه...');
        notifyListeners();

        await _waitWithCheck(delay);
      }
    }

    _isRunning = false;
    _currentMessage = 'عملیات فالو پیج هدف به پایان رسید';
    addLog('🎉 پایان عملیات فالو پیج هدف.');
    notifyListeners();
  }

  Future<void> _waitWithCheck(int seconds) async {
    for (int i = 0; i < seconds; i++) {
      if (!_isRunning) break;
      while (_isPaused) {
        await Future.delayed(const Duration(seconds: 1));
        if (!_isRunning) break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
  }
}
