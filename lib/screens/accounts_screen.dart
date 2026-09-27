import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instagram_account.dart';
import '../providers/account_provider.dart';
import '../services/instagram_api_service.dart';
import 'add_account_screen.dart';
import 'bulk_import_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Color _getStatusColor(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return Colors.green;
      case AccountStatus.rateLimited:
        return Colors.orange;
      case AccountStatus.challengeRequired:
        return Colors.red;
      case AccountStatus.disabled:
        return Colors.grey;
    }
  }

  String _getStatusText(AccountStatus status) {
    switch (status) {
      case AccountStatus.active:
        return 'فعال';
      case AccountStatus.rateLimited:
        return 'محدودیت موقت (Block)';
      case AccountStatus.challengeRequired:
        return 'تایید امنیتی (Challenge)';
      case AccountStatus.disabled:
        return 'غیرفعال';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مدیریت اکانت‌های اینستاگرام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'ورود گروهی اکانت‌ها (Bulk Import)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BulkImportScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'افزودن اکانت جدید با WebView',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddAccountScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: accountProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : accountProvider.accounts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_circle_outlined,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'هنوز هیچ اکانتی اضافه نشده است.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('افزودن اکانت اینستاگرام'),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddAccountScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: accountProvider.accounts.length,
                  itemBuilder: (context, index) {
                    final account = accountProvider.accounts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _getStatusColor(account.status).withOpacity(0.2),
                          child: Icon(
                            Icons.person,
                            color: _getStatusColor(account.status),
                          ),
                        ),
                        title: Text(
                          '@${account.username}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(account.status)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _getStatusText(account.status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: _getStatusColor(account.status),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'تعداد فالو امروز: ${account.followsCountToday}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'delete') {
                              accountProvider.removeAccount(account.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'اکانت @${account.username} حذف شد.'),
                                ),
                              );
                            } else if (value == 'check') {
                              final apiService = InstagramApiService();
                              final isValid = await apiService
                                  .checkSessionHealth(account);
                              if (context.mounted) {
                                if (isValid) {
                                  accountProvider.updateAccountStatus(
                                      account.id, AccountStatus.active);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '✅ نشست اکانت معتبر و فعال است.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  accountProvider.updateAccountStatus(
                                      account.id,
                                      AccountStatus.challengeRequired);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '⚠️ نشست انقضا یافته یا نیاز به ورود مجدد دارد.'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'check',
                              child: Row(
                                children: [
                                  Icon(Icons.health_and_safety, size: 20),
                                  SizedBox(width: 8),
                                  Text('بررسی وضعیت نشست'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete,
                                      color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('حذف اکانت',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddAccountScreen(),
            ),
          );
        },
        tooltip: 'افزودن اکانت',
        child: const Icon(Icons.add),
      ),
    );
  }
}
