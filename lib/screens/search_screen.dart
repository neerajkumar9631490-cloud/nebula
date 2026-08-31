import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
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
  late TMDBService _service;

  @override
  void initState() {
    super.initState();
    _service = TMDBService(widget.apiKey);
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _loading = true);
      final results = await _service.search(query);
      if (mounted) setState(() { _results = results; _loading = false; });
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
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search movies or TV shows...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final item = _results[index];
                      return ListTile(
                        leading: item.posterPath != null
                            ? CachedNetworkImage(imageUrl: _service.getImgUrl(item.posterPath), width: 50, fit: BoxFit.cover)
                            : const Icon(Icons.movie),
                        title: Text(item.title),
                        subtitle: Text('${item.releaseYear} • ${item.mediaType.toUpperCase()}'),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(item: item, apiKey: widget.apiKey))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
