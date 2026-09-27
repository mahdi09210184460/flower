import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../models/instagram_account.dart';
import '../providers/account_provider.dart';
import 'bulk_import_screen.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _isProcessingAccount = false;
  String _statusText = 'در حال استخراج نشست و کوکی‌ها...';
  String? _errorMessage;

  Future<void> _checkAndExtractCookies(WebUri? url) async {
    if (_isProcessingAccount || url == null) return;

    final urlString = url.toString();
    // After successful login, Instagram redirects to home, one-tap, or profile
    if (urlString.contains('instagram.com') &&
        !urlString.contains('/accounts/login/') &&
        !urlString.contains('/accounts/emailsignup/')) {
      setState(() {
        _isProcessingAccount = true;
        _errorMessage = null;
      });

      try {
        final cookieManager = CookieManager.instance();
        final cookies = await cookieManager.getCookies(
          url: WebUri('https://www.instagram.com'),
        );

        final Map<String, String> cookieMap = {};
        for (var cookie in cookies) {
          cookieMap[cookie.name] = cookie.value.toString();
        }

        final sessionId = cookieMap['sessionid'];
        final dsUserId = cookieMap['ds_user_id'];

        if (sessionId != null && sessionId.isNotEmpty && dsUserId != null) {
          // Get User-Agent
          String userAgent = '';
          if (_webViewController != null) {
            final uaResult = await _webViewController!
                .evaluateJavascript(source: 'navigator.userAgent');
            if (uaResult != null) {
              userAgent = uaResult.toString().replaceAll('"', '');
            }
          }

          // Try to extract username from JavaScript or HTML
          String username = 'user_$dsUserId';
          try {
            final jsResult = await _webViewController?.evaluateJavascript(
              source:
                  'window._sharedData?.config?.viewer?.username || document.querySelector("a[href*=\'/$dsUserId\']")?.textContent',
            );
            if (jsResult != null &&
                jsResult.toString() != 'null' &&
                jsResult.toString().isNotEmpty) {
              username = jsResult.toString().replaceAll('"', '');
            }
          } catch (_) {}

          final newAccount = InstagramAccount(
            id: dsUserId,
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
              content: Text('✅ اکانت @$username با موفقیت اضافه شد!'),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.of(context).pop();
        } else {
          setState(() {
            _isProcessingAccount = false;
          });
        }
      } catch (e) {
        setState(() {
          _isProcessingAccount = false;
          _errorMessage = 'خطا در استخراج کوکی: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('ورود به اکانت اینستاگرام'),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.web_asset_off_rounded,
                      size: 64,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'محدودیت اجرا در مرورگر کروم (Web)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'وب‌سایت اینستاگرام به دلایل امنیتی (CORS / X-Frame-Options) اجازه نمایش فرم ورود داخل iframe مرورگر وب را نمی‌دهد.\n\nبرای اضافه کردن اکانت در نسخه وب، از روش «ورود گروهی با کوکی» استفاده کنید یا برنامه را روی شبیه‌ساز/دستگاه اندروید اجرا نمایید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.file_upload),
                      label: const Text('ورود به صفحه ورود گروهی با کوکی'),
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
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ورود به اکانت اینستاگرام'),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4.0),
                child: LinearProgressIndicator(),
              )
            : null,
        actions: [
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
                    url: WebUri('https://m.instagram.com/accounts/login/'),
                  ),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    useShouldOverrideUrlLoading: true,
                    domStorageEnabled: true,
                    thirdPartyCookiesEnabled: true,
                    cacheEnabled: true,
                    userAgent:
                        'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                  ),
                  onWebViewCreated: (controller) {
                    _webViewController = controller;
                  },
                  onLoadStart: (controller, url) {
                    setState(() {
                      _isLoading = true;
                    });
                  },
                  onLoadStop: (controller, url) async {
                    setState(() {
                      _isLoading = false;
                    });
                    await _checkAndExtractCookies(url);
                  },
                  onReceivedError: (controller, request, error) {
                    setState(() {
                      _isLoading = false;
                      _errorMessage =
                          'خطا در بارگذاری صفحه: ${error.description}\nلطفاً فیلترشکن (VPN) خود را بررسی کنید.';
                    });
                  },
                  onUpdateVisitedHistory: (controller, url, isReload) async {
                    await _checkAndExtractCookies(url);
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
