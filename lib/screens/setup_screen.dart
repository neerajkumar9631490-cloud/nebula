import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';

class SetupScreen extends StatefulWidget {
  final Function(String) onKeySaved;
  const SetupScreen({super.key, required this.onKeySaved});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _validateAndSave() async {
    setState(() { _loading = true; _error = null; });
    final service = TMDBService(_controller.text.trim());
    final isValid = await service.validateKey();

    if (isValid) {
      widget.onKeySaved(_controller.text.trim());
    } else {
      setState(() { _error = 'Invalid API Key or network error.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.stroke),
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 52, color: AppTheme.accent),
              ),
              const SizedBox(height: 24),
              const Text(
                'MOVIX',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 6, color: AppTheme.text),
              ),
              const SizedBox(height: 8),
              const Text(
                'Every stream. One app.',
                style: TextStyle(color: AppTheme.textDim),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _controller,
                style: const TextStyle(color: AppTheme.text),
                decoration: InputDecoration(
                  labelText: 'TMDB API Key',
                  errorText: _error,
                  prefixIcon: const Icon(Icons.key_rounded),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _loading ? null : _validateAndSave,
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save & Start'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
