import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instagram_account.dart';
import '../providers/account_provider.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isImporting = false;
  String _resultMessage = '';

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _processBulkImport() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isImporting = true;
      _resultMessage = 'در حال پردازش و افزودن اکانت‌ها...';
    });

    final lines = text.split('\n');
    int addedCount = 0;
    int errorCount = 0;

    final accountProvider =
        Provider.of<AccountProvider>(context, listen: false);

    for (var line in lines) {
      final cleanLine = line.trim();
      if (cleanLine.isEmpty) continue;

      try {
        // Supported format 1: username|sessionid|ds_user_id|csrftoken
        // Supported format 2: cookie header string "sessionid=...; ds_user_id=...; csrftoken=..."
        if (cleanLine.contains('|')) {
          final parts = cleanLine.split('|');
          if (parts.length >= 3) {
            final username = parts[0].trim();
            final sessionId = parts[1].trim();
            final dsUserId = parts[2].trim();
            final csrfToken = parts.length > 3 ? parts[3].trim() : '';

            final account = InstagramAccount(
              id: dsUserId,
              username: username,
              cookies: {
                'sessionid': sessionId,
                'ds_user_id': dsUserId,
                if (csrfToken.isNotEmpty) 'csrftoken': csrfToken,
              },
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              status: AccountStatus.active,
            );

            await accountProvider.addOrUpdateAccount(account);
            addedCount++;
          }
        } else if (cleanLine.contains('sessionid=')) {
          // Parse cookie string format
          final Map<String, String> cookieMap = {};
          final pairs = cleanLine.split(';');
          for (var p in pairs) {
            final kv = p.trim().split('=');
            if (kv.length >= 2) {
              cookieMap[kv[0].trim()] = kv.sublist(1).join('=').trim();
            }
          }

          final sessionId = cookieMap['sessionid'];
          final dsUserId = cookieMap['ds_user_id'] ??
              'user_${DateTime.now().millisecondsSinceEpoch}';

          if (sessionId != null) {
            final account = InstagramAccount(
              id: dsUserId,
              username: 'user_$dsUserId',
              cookies: cookieMap,
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
              status: AccountStatus.active,
            );

            await accountProvider.addOrUpdateAccount(account);
            addedCount++;
          }
        } else {
          errorCount++;
        }
      } catch (e) {
        errorCount++;
      }
    }

    setState(() {
      _isImporting = false;
      _resultMessage =
          '✅ افزودن گروهی به پایان رسید:\n$addedCount اکانت موفقانه اضافه شد.\n$errorCount خطای فرمت.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('افزودن گروهی اکانت‌ها (Bulk Import)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'راهنمای فرمت ورود گروهی (تعداد بالا مثلا ۵۰۰ اکانت):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'فرمت ۱ (با خط عمودی):\nusername|sessionid|ds_user_id|csrftoken\n\nفرمت ۲ (رشته کوکی):\nsessionid=XXX; ds_user_id=YYY; csrftoken=ZZZ',
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'اطلاعات اکانت‌ها را هر کدام در یک خط وارد کنید...',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isImporting,
              ),
            ),
            const SizedBox(height: 12),
            if (_resultMessage.isNotEmpty) ...[
              Text(
                _resultMessage,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              icon: _isImporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.file_upload),
              label: Text(_isImporting
                  ? 'در حال افزودن...'
                  : 'افزودن همه اکانت‌ها به برنامه'),
              onPressed: _isImporting ? null : _processBulkImport,
            ),
          ],
        ),
      ),
    );
  }
}
