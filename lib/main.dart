import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/setup_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? _apiKey;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey = prefs.getString('tmdb_api_key');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nebula',
      theme: ThemeData.dark(useMaterial3: true),
      home: _apiKey == null
          ? SetupScreen(onKeySaved: (key) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('tmdb_api_key', key);
              setState(() => _apiKey = key);
            })
          : HomeScreen(apiKey: _apiKey!),
    );
  }
}
