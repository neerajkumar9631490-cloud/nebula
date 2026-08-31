import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      theme: ThemeData.dark(useMaterial3: true),
      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _apiKey == null
              ? SetupScreen(onKeySaved: _saveKey)
              : HomeScreen(
                  apiKey: _apiKey!,
                  onResetKey: _resetKey,
                ),
    );
  }
}
