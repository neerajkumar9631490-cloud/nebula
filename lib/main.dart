import 'dart:async';
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

  /// Seeds the built-in catalog plugin, then shows the app immediately.
  /// Everything else (music prefs, lossless session, download index,
  /// torrent engine) warms up in the background — the old code gated
  /// the whole UI on a 650ms delay plus the slowest of those inits.
  Future<void> _init() async {
    unawaited(MusicSettings.instance.ensureLoaded());
    unawaited(LosslessAudioService.instance.initialize());
    unawaited(MusicDownloadService.instance.init());
    unawaited(TorrServerBackend().ensureReady());
    await AddonManager.ensureSeeded();
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

  /// Tabs build on first visit and stay alive after — the old code
  /// constructed all six screens (home, search-hot, library, music,
  /// addons, settings) on startup, firing every network load at once.
  final Map<int, Widget> _built = {};

  Widget _body(int index, VoidCallback onSearchTap) {
    return _built.putIfAbsent(index, () {
      switch (index) {
        case 0:
          return HomeScreen(onSearchTap: onSearchTap);
        case 1:
          return const SearchScreen();
        case 2:
          return const LibraryScreen();
        case 3:
          return const MusicHomeScreen();
        case 4:
          return const AddonsScreen();
        case 5:
          return const SettingsScreen();
        default:
          return const SizedBox.shrink();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    void goSearch() => setState(() => _tab = 1);
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          for (var i = 0; i < 6; i++)
            (i == _tab || _built.containsKey(i))
                ? _body(i, goSearch)
                : const SizedBox.shrink(),
        ],
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
