import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'services/torrent/torrent_service.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/addons_screen.dart';
import 'screens/settings_screen.dart';

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
    // Small staged delay so the splash feels intentional, not flickery.
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _apiKey = prefs.getString('tmdb_api_key');
      _loading = false;
    });
  }

  Future<void> _saveKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tmdb_api_key', key);
    if (mounted) setState(() => _apiKey = key);
  }

  Future<void> _resetKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tmdb_api_key');
    if (mounted) setState(() => _apiKey = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: AnimatedSwitcher(
        duration: AppTheme.med,
        switchInCurve: AppTheme.curve,
        child: _loading
            ? const _SplashScreen(key: ValueKey('splash'))
            : _apiKey == null
                ? SetupScreen(key: const ValueKey('setup'), onKeySaved: _saveKey)
                : MainShell(
                    key: const ValueKey('main'),
                    apiKey: _apiKey!,
                    onResetKey: _resetKey,
                    onKeyChanged: _saveKey,
                  ),
      ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({super.key});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _scale = Tween<double>(begin: 0.86, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: AppTheme.curve));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B1F15), AppTheme.bg, Color(0xFF0A1420)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 54, color: AppTheme.onAccent),
                  ),
                  const SizedBox(height: 22),
                  const Text('MOVIX',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: AppTheme.text)),
                  const SizedBox(height: 8),
                  const Text('Every stream. One app.',
                      style: TextStyle(color: AppTheme.textDim, fontSize: 13.5)),
                  const SizedBox(height: 30),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final String apiKey;
  final VoidCallback onResetKey;
  final ValueChanged<String> onKeyChanged;

  const MainShell(
      {super.key,
      required this.apiKey,
      required this.onResetKey,
      required this.onKeyChanged});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: AnimatedSwitcher(
        duration: AppTheme.fast,
        switchInCurve: AppTheme.curve,
        child: IndexedStack(
          key: ValueKey(_tab),
          index: _tab,
          children: [
            HomeScreen(
                key: ValueKey('home-${widget.apiKey}'),
                apiKey: widget.apiKey,
                onResetKey: widget.onResetKey),
            SearchScreen(
                key: ValueKey('search-${widget.apiKey}'),
                apiKey: widget.apiKey),
            const AddonsScreen(),
            SettingsScreen(
              apiKey: widget.apiKey,
              onResetKey: widget.onResetKey,
              onKeyChanged: widget.onKeyChanged,
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.stroke, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          animationDuration: AppTheme.med,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Search',
            ),
            NavigationDestination(
              icon: Icon(Icons.extension_outlined),
              selectedIcon: Icon(Icons.extension_rounded),
              label: 'Add-ons',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
