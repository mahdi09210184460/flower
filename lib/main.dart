import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/account_provider.dart';
import 'screens/accounts_screen.dart';
import 'screens/mutual_follow_screen.dart';
import 'screens/target_follow_screen.dart';
import 'services/automation_queue_service.dart';
import 'services/instagram_api_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = await StorageService.init();
  final apiService = InstagramApiService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AccountProvider(storageService),
        ),
        ChangeNotifierProvider(
          create: (_) => AutomationQueueService(apiService),
        ),
      ],
      child: const FlowerBegirApp(),
    ),
  );
}

class FlowerBegirApp extends StatelessWidget {
  const FlowerBegirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'فالوور بگیر - مدیریت اکانت‌های اینستاگرام',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AccountsScreen(),
    MutualFollowScreen(),
    TargetFollowScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'اکانت‌ها',
            ),
            NavigationDestination(
              icon: Icon(Icons.sync_outlined),
              selectedIcon: Icon(Icons.sync),
              label: 'فالو متقابل',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_add_outlined),
              selectedIcon: Icon(Icons.person_add),
              label: 'فالو پیج هدف',
            ),
          ],
        ),
      ),
    );
  }
}
