import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';

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
      appBar: AppBar(title: const Text('Nebula Setup')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Enter your TMDB API Key to continue:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'API Key',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _validateAndSave,
              child: _loading ? const CircularProgressIndicator() : const Text('Save & Start'),
            )
          ],
        ),
      ),
    );
  }
}
