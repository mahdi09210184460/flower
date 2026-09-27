import 'package:flutter/foundation.dart';
import '../models/instagram_account.dart';
import '../services/storage_service.dart';

class AccountProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<InstagramAccount> _accounts = [];
  bool _isLoading = true;

  int _minDelaySeconds = 30;
  int _maxDelaySeconds = 120;

  List<InstagramAccount> get accounts => List.unmodifiable(_accounts);
  bool get isLoading => _isLoading;
  int get minDelaySeconds => _minDelaySeconds;
  int get maxDelaySeconds => _maxDelaySeconds;

  int get activeAccountsCount =>
      _accounts.where((a) => a.status == AccountStatus.active).length;

  AccountProvider(this._storageService) {
    _loadData();
  }

  Future<void> _loadData() async {
    _isLoading = true;
    notifyListeners();

    _accounts = await _storageService.loadAccounts();
    _minDelaySeconds = _storageService.minDelaySeconds;
    _maxDelaySeconds = _storageService.maxDelaySeconds;

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addOrUpdateAccount(InstagramAccount account) async {
    final index = _accounts.indexWhere((a) => a.id == account.id);
    if (index >= 0) {
      _accounts[index] = account;
    } else {
      _accounts.add(account);
    }
    await _storageService.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> removeAccount(String accountId) async {
    _accounts.removeWhere((a) => a.id == accountId);
    await _storageService.saveAccounts(_accounts);
    notifyListeners();
  }

  Future<void> updateDelays(int minSeconds, int maxSeconds) async {
    _minDelaySeconds = minSeconds;
    _maxDelaySeconds = maxSeconds;
    await _storageService.saveDelays(minSeconds, maxSeconds);
    notifyListeners();
  }

  Future<void> updateAccountStatus(
      String accountId, AccountStatus newStatus) async {
    final index = _accounts.indexWhere((a) => a.id == accountId);
    if (index >= 0) {
      _accounts[index] = _accounts[index].copyWith(status: newStatus);
      await _storageService.saveAccounts(_accounts);
      notifyListeners();
    }
  }
}
