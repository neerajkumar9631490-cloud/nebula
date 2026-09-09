import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'theme/app_theme.dart';
import 'widgets/app_logo.dart';
import 'streaming/torrserver_backend.dart';
import 'services/stremio/addon_manager.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/library_screen.dart';
import 'screens/addons_screen.dart';
import 'screens/settings_screen.dart';
import 'music/screens/music_home_screen.dart';
import 'music/services/lossless_audio_service.dart';
import 'music/services/music_download_service.dart';
import 'music/services/music_settings.dart';
import 'music/widgets/mini_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  // Pre-warm engine + loopback server behind the backend interface.
  TorrServerBackend().ensureReady();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  /// Seeds the built-in catalog plugin on first launch so categories,
  /// search and artwork work instantly — no API key, no setup screen.
  Future<void> _init() async {
    await Future.wait([
      AddonManager.ensureSeeded(),
      MusicSettings.instance.ensureLoaded(),
      LosslessAudioService.instance.initialize(),
      MusicDownloadService.instance.init(),
      // Small staged delay so the splash feels intentional, not flickery.
      Future.delayed(const Duration(milliseconds: 650)),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
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
            : const MainShell(key: ValueKey('main')),
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
                  const AppLogo(size: 112, radius: 30),
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
  const MainShell({super.key});

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
            HomeScreen(onSearchTap: () => setState(() => _tab = 1)),
            const SearchScreen(),
            const LibraryScreen(),
            const MusicHomeScreen(),
            const AddonsScreen(),
            const SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          Container(
            decoration: const BoxDecoration(
              border:
                  Border(top: BorderSide(color: AppTheme.stroke, width: 1)),
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
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            NavigationDestination(
              icon: Icon(Icons.video_library_outlined),
              selectedIcon: Icon(Icons.video_library_rounded),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined),
              selectedIcon: Icon(Icons.music_note_rounded),
              label: 'Music',
            ),
            NavigationDestination(
              icon: Icon(Icons.extension_outlined),
              selectedIcon: Icon(Icons.extension_rounded),
              label: 'Addons',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
      ],
      ),
    );
  }
}
