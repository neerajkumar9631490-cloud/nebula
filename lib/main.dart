import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/torrent/torrent_service.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/addons_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  TorrentService().initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _apiKey;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('tmdb_api_key');
      _loading = false;
    });
  }

  Future<void> _saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tmdb_api_key', key);
    setState(() => _apiKey = key);
  }

  Future<void> _resetKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tmdb_api_key');
    setState(() => _apiKey = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nebula',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _apiKey == null
              ? SetupScreen(onKeySaved: _saveKey)
              : MainShell(apiKey: _apiKey!, onResetKey: _resetKey),
    );
  }
}

class MainShell extends StatefulWidget {
  final String apiKey;
  final VoidCallback onResetKey;

  const MainShell({super.key, required this.apiKey, required this.onResetKey});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(apiKey: widget.apiKey, onResetKey: widget.onResetKey),
          SearchScreen(apiKey: widget.apiKey),
          const AddonsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search_rounded), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.extension_rounded), label: 'Add-ons'),
        ],
      ),
    );
  }
}
