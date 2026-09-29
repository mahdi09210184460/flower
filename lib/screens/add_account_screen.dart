import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/instagram_account.dart';
import '../providers/account_provider.dart';
import 'bulk_import_screen.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _sessionIdController = TextEditingController();
  final TextEditingController _dsUserIdController = TextEditingController();
  bool _isLoading = false;

  InAppWebViewController? _webViewController;
  bool _isProcessingAccount = false;
  String _statusText = 'در حال بررسی نشست و کوکی‌ها...';
  String? _errorMessage;

  Timer? _cookieCheckTimer;

  final String _loginUrl = 'https://www.instagram.com/accounts/login/';

  @override
  void initState() {
    super.initState();
    // Periodically check every 1 second for native sessionid cookie
    _cookieCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isProcessingAccount && _webViewController != null && !kIsWeb) {
        _checkAndExtractCookiesFast();
      }
    });
  }

  @override
  void dispose() {
    _cookieCheckTimer?.cancel();
    _usernameController.dispose();
    _sessionIdController.dispose();
    _dsUserIdController.dispose();
    super.dispose();
  }

  Future<void> _checkAndExtractCookiesFast() async {
    if (_webViewController == null) return;

    try {
      final cookieManager = CookieManager.instance();
      final domains = [
        WebUri('https://www.instagram.com'),
        WebUri('https://m.instagram.com'),
        WebUri('https://instagram.com'),
      ];

      final Map<String, String> cookieMap = {};
      for (var uri in domains) {
        try {
          final cookies = await cookieManager.getCookies(url: uri);
          for (var c in cookies) {
            if (c.name.isNotEmpty && c.value != null && c.value.toString().isNotEmpty) {
              cookieMap[c.name] = c.value.toString();
            }
          }
        } catch (_) {}
      }

      // Fallback: parse document.cookie via JS
      try {
        final jsCookies = await _webViewController?.evaluateJavascript(
          source: 'document.cookie',
        );
        if (jsCookies != null) {
          final str = jsCookies.toString().replaceAll('"', '');
          for (var pair in str.split(';')) {
            final parts = pair.trim().split('=');
            if (parts.length >= 2) {
              cookieMap[parts[0].trim()] = parts.sublist(1).join('=').trim();
            }
          }
        }
      } catch (_) {}

      final sessionId = cookieMap['sessionid'];
      final dsUserId = cookieMap['ds_user_id'];

      if (sessionId != null && sessionId.isNotEmpty) {
        _cookieCheckTimer?.cancel();
        if (mounted) {
          setState(() {
            _isProcessingAccount = true;
            _statusText = 'ورود موفقیت‌آمیز تشخیص داده شد! در حال ثبت اکانت...';
          });
        }

        final userId = dsUserId ?? 'user_${DateTime.now().millisecondsSinceEpoch}';

        String userAgent = '';
        try {
          final uaResult = await _webViewController!
              .evaluateJavascript(source: 'navigator.userAgent');
          if (uaResult != null) {
            userAgent = uaResult.toString().replaceAll('"', '');
          }
        } catch (_) {}

        String username = 'user_$userId';
        try {
          final jsResult = await _webViewController?.evaluateJavascript(
            source:
                'window._sharedData?.config?.viewer?.username || (document.querySelector("a[href*=\'/$userId\']")?.textContent) || window.location.pathname.replace(/\\//g, "")',
          );
          if (jsResult != null &&
              jsResult.toString() != 'null' &&
              jsResult.toString().isNotEmpty) {
            final val = jsResult.toString().replaceAll('"', '').trim();
            if (val.isNotEmpty &&
                !val.contains('accounts') &&
                !val.contains('login') &&
                !val.contains('challenge') &&
                !val.contains('standard')) {
              username = val;
            }
          }
        } catch (_) {}

        final newAccount = InstagramAccount(
          id: userId,
          username: username,
          cookies: cookieMap,
          userAgent: userAgent,
          status: AccountStatus.active,
        );

        if (!mounted) return;
        final accountProvider =
            Provider.of<AccountProvider>(context, listen: false);

        await accountProvider.addOrUpdateAccount(newAccount);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ اکانت @$username با موفقیت وارد و ثبت شد!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.of(context).pop();
      } else {
        if (_isProcessingAccount && mounted) {
          setState(() {
            _isProcessingAccount = false;
          });
        }
      }
    } catch (_) {
      if (_isProcessingAccount && mounted) {
        setState(() {
          _isProcessingAccount = false;
        });
      }
    }
  }

  Future<void> _addAccountByCookie() async {
    final username = _usernameController.text.trim().replaceAll('@', '');
    final sessionId = _sessionIdController.text.trim();
    final dsUserId = _dsUserIdController.text.trim();

    if (username.isEmpty || sessionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لطفاً نام کاربری و Session ID را وارد کنید.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = dsUserId.isNotEmpty
          ? dsUserId
          : DateTime.now().millisecondsSinceEpoch.toString();

      final account = InstagramAccount(
        id: userId,
        username: username,
        cookies: {
          'sessionid': sessionId,
          'ds_user_id': userId,
        },
        userAgent:
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        status: AccountStatus.active,
      );

      if (!mounted) return;
      final accountProvider =
          Provider.of<AccountProvider>(context, listen: false);
      await accountProvider.addOrUpdateAccount(account);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ اکانت @$username با موفقیت اضافه شد!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطا در ثبت اکانت: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _extractAndSaveAccountManually() async {
    setState(() {
      _isProcessingAccount = true;
      _statusText = 'در حال استخراج کوکی‌ها و ثبت اکانت...';
    });

    await _checkAndExtractCookiesFast();

    if (!_isProcessingAccount && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '⚠️ هنوز کوکی sessionid یافت نشد. لطفاً مطمئن شوید که کاملاً لاگین کرده‌اید.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('افزودن اکانت در نسخه وب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.file_upload),
              tooltip: 'ورود گروهی با کوکی',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BulkImportScreen(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.open_in_new,
                          size: 48, color: Colors.deepPurple),
                      const SizedBox(height: 16),
                      const Text(
                        'راهنمای ورود در نسخه وب (Chrome):',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '۱. دکمه زیر را بزنید تا صفحه ورود اینستاگرام در یک تب جدید در مرورگر باز شود.\n'
                        '۲. وارد اکانت خود شوید.\n'
                        '۳. کلید F12 را بزنید، به تب Application ➔ Cookies بروید و مقدار sessionid را کپی کنید.\n'
                        '۴. نام کاربری و sessionid را در فرم زیر وارد کنید.',
                        style: TextStyle(
                            fontSize: 13, height: 1.6, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.open_in_browser),
                        label: const Text('باز کردن صفحه ورود اینستاگرام در تب جدید'),
                        onPressed: () async {
                          final uri = Uri.parse(_loginUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri,
                                mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                      const Divider(height: 32),
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'نام کاربری (Username)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _sessionIdController,
                        decoration: const InputDecoration(
                          labelText: 'کوکی sessionid',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.vpn_key),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _isLoading ? null : _addAccountByCookie,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('ثبت و افزودن اکانت'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ورود به اینستاگرام'),
        actions: [
          // Manual Save Button
          IconButton(
            icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
            tooltip: 'ثبت این اکانت (تایید ورود)',
            onPressed: _extractAndSaveAccountManually,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'بارگذاری مجدد',
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
              _webViewController?.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_errorMessage != null)
                Container(
                  color: Colors.red.shade100,
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(
                    url: WebUri(_loginUrl),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    cacheEnabled: true,
                    transparentBackground: false,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {},
                  onLoadStop: (controller, url) async {
                    await _checkAndExtractCookiesFast();
                  },
                  onReceivedError: (controller, request, error) {
                    setState(() {
                      _errorMessage =
                          'خطا در بارگذاری صفحه: ${error.description}\nلطفاً فیلترشکن (VPN) خود را بررسی کنید.';
                    });
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) async {
                    await _checkAndExtractCookiesFast();
                  },
                ),
              ),
            ],
          ),
          if (_isProcessingAccount)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _statusText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
