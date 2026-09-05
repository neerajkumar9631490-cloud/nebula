import 'package:flutter/material.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SetupScreen extends StatefulWidget {
  final Function(String) onKeySaved;
  const SetupScreen({super.key, required this.onKeySaved});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: AppTheme.curve));
  }

  @override
  void dispose() {
    _c.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validateAndSave() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please paste your TMDB API key first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ok = await TMDBService(key).validateKey();
      if (!mounted) return;
      if (ok) {
        widget.onKeySaved(key);
        return;
      }
      setState(() {
        _error = 'Invalid API key or network error. Try again.';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not reach TMDB. Check connection and retry.';
        _loading = false;
      });
    }
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
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              physics: const BouncingScrollPhysics(),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          shape: BoxShape.circle,
                          boxShadow: AppTheme.glowShadow,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 52, color: AppTheme.onAccent),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'MOVIX',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 8,
                            color: AppTheme.text),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Every stream. One app.',
                        style: TextStyle(color: AppTheme.textDim, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.stroke),
                        ),
                        child: const Text('STEP 1 OF 2  •  CONNECT TMDB',
                            style: TextStyle(
                                color: AppTheme.textDim,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1)),
                      ),
                      const SizedBox(height: 32),
                      GlassCard(
                        radius: 20,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.key_rounded,
                                    size: 18, color: AppTheme.accent),
                                SizedBox(width: 8),
                                Text('TMDB API Key',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.text,
                                        fontSize: 15)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Get a free key from themoviedb.org → Settings → API, then paste it below.',
                              style: TextStyle(
                                  color: AppTheme.textDim, fontSize: 13, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _controller,
                              obscureText: _obscure,
                              style: const TextStyle(color: AppTheme.text),
                              decoration: InputDecoration(
                                hintText: 'Paste API key here',
                                errorText: _error,
                                prefixIcon: const Icon(Icons.vpn_key_rounded),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                              ),
                              onSubmitted: (_) => _validateAndSave(),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: Pressable(
                                onTap: _loading ? null : _validateAndSave,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.accentGradient,
                                    borderRadius:
                                        BorderRadius.circular(AppTheme.rMd),
                                    boxShadow: AppTheme.glowShadow,
                                  ),
                                  child: Center(
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.onAccent),
                                          )
                                        : const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Save & Start Watching',
                                                  style: TextStyle(
                                                      color: AppTheme.onAccent,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 15)),
                                              SizedBox(width: 8),
                                              Icon(Icons.arrow_forward_rounded,
                                                  color: AppTheme.onAccent,
                                                  size: 19),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Your key stays on this device only.',
                          style: TextStyle(color: AppTheme.textFaint, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
