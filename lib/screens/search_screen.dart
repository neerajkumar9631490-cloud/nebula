import 'dart:async';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import '../theme/app_theme.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String apiKey;
  const SearchScreen({super.key, required this.apiKey});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _results = [];
  bool _loading = false;
  bool _searched = false;
  late TMDBService _service;

  @override
  void initState() {
    super.initState();
    _service = TMDBService(widget.apiKey);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().isEmpty) {
        setState(() { _results = []; _searched = false; });
        return;
      }
      setState(() => _loading = true);
      final results = await _service.search(query);
      if (mounted) setState(() { _results = results; _loading = false; _searched = true; });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: AppTheme.text),
              decoration: const InputDecoration(
                hintText: 'Movies, TV shows...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : !_searched
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.explore_rounded, size: 56, color: AppTheme.cardHi),
                            SizedBox(height: 12),
                            Text('Discover something new',
                                style: TextStyle(color: AppTheme.textDim)),
                          ],
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text('No results found', style: TextStyle(color: AppTheme.textDim)),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.56,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 12,
                            ),
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DetailScreen(item: item, apiKey: widget.apiKey)),
                                ),
                                child: PosterCard(item: item, apiKey: widget.apiKey),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
