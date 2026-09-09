import '../models/music_models.dart';

enum MusicRepeatMode { off, all, one }

/// Centralized playback queue — the ONLY queue in the music feature.
/// All screens share it through [MusicPlayerController]; there are no
/// per-screen queues.
///
/// Play order lives in [_order] (item indices). With shuffle off it is
/// always the identity; with shuffle on it is a permutation with the
/// current item first. Structural edits preserve the playing item.
class MusicQueue {
  final List<QueueItem> _items = [];
  List<int> _order = [];
  int _pos = -1;
  bool shuffle = false;
  MusicRepeatMode repeat = MusicRepeatMode.off;

  List<QueueItem> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;

  /// 0-based position in play order, -1 when nothing is cued.
  int get position => (_pos >= 0 && _pos < _order.length) ? _pos : -1;

  QueueItem? get current {
    final p = position;
    if (p < 0) return null;
    final ix = _order[p];
    return (ix >= 0 && ix < _items.length) ? _items[ix] : null;
  }

  void setQueue(List<Track> tracks, {int startIndex = 0}) {
    _items
      ..clear()
      ..addAll(tracks.map((t) => QueueItem(track: t)));
    if (_items.isEmpty) {
      _order = [];
      _pos = -1;
      return;
    }
    final start = startIndex.clamp(0, _items.length - 1);
    _normalize(keepId: _items[start].queueId);
  }

  void add(Track track) {
    final keepId = current?.queueId;
    _items.add(QueueItem(track: track));
    _normalize(keepId: keepId);
  }

  void addAll(List<Track> tracks) {
    if (tracks.isEmpty) return;
    final keepId = current?.queueId;
    _items.addAll(tracks.map((t) => QueueItem(track: t)));
    _normalize(keepId: keepId);
  }

  /// Queues [track] to play right after the current one.
  void insertNext(Track track) {
    final keepId = current?.queueId;
    final item = QueueItem(track: track);
    var at = _items.length;
    if (position >= 0) at = (_order[position] + 1).clamp(0, _items.length);
    _items.insert(at, item);
    _normalize(keepId: keepId);
    if (shuffle && _items.length > 1 && position >= 0) {
      final ix = _items.indexWhere((e) => e.queueId == item.queueId);
      _order.remove(ix);
      _order.insert((position + 1).clamp(0, _order.length), ix);
    }
  }

  /// Removes the item at [itemIndex]. Returns the item now at the
  /// playback position (to continue with), or null when empty.
  QueueItem? removeAt(int itemIndex) {
    if (itemIndex < 0 || itemIndex >= _items.length) return current;
    final curId = current?.queueId;
    final removedCurrent =
        curId != null && _items[itemIndex].queueId == curId;
    final oldPos = position;
    _items.removeAt(itemIndex);
    if (_items.isEmpty) {
      _order = [];
      _pos = -1;
      return null;
    }
    if (removedCurrent) {
      _normalize();
      if (!shuffle) {
        // Continue with whatever slid into the removed slot.
        _pos = oldPos.clamp(0, _order.length - 1);
      }
    } else {
      _normalize(keepId: curId);
    }
    return current;
  }

  void move(int oldItemIndex, int newItemIndex) {
    if (oldItemIndex < 0 ||
        oldItemIndex >= _items.length ||
        newItemIndex < 0 ||
        newItemIndex >= _items.length ||
        oldItemIndex == newItemIndex) return;
    final keepId = current?.queueId;
    final item = _items.removeAt(oldItemIndex);
    _items.insert(newItemIndex, item);
    _normalize(keepId: keepId);
  }

  void clear() {
    _items.clear();
    _order = [];
    _pos = -1;
  }

  /// Full stop: items stay queued, nothing is cued for playback.
  void stopPlayback() {
    _pos = -1;
  }

  /// Advances honoring repeat-all. Returns the next item, or null at
  /// the end (repeat off) / when empty.
  QueueItem? next() {
    if (_items.isEmpty) return null;
    if (position + 1 < _order.length) {
      _pos = position + 1;
      return current;
    }
    if (repeat == MusicRepeatMode.all) {
      _pos = 0;
      return current;
    }
    return null;
  }

  /// Steps back. Returns null at the head (caller restarts the track).
  QueueItem? previous() {
    if (_items.isEmpty || position <= 0) return null;
    _pos = position - 1;
    return current;
  }

  /// Cues the item at [itemIndex]. Returns it (never null when valid).
  QueueItem? playAt(int itemIndex) {
    if (itemIndex < 0 || itemIndex >= _items.length) return current;
    _pos = _order.indexOf(itemIndex);
    if (_pos < 0) _pos = 0;
    return current;
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    if (_items.isNotEmpty) _normalize(keepId: current?.queueId);
  }

  MusicRepeatMode cycleRepeat() {
    repeat = switch (repeat) {
      MusicRepeatMode.off => MusicRepeatMode.all,
      MusicRepeatMode.all => MusicRepeatMode.one,
      MusicRepeatMode.one => MusicRepeatMode.off,
    };
    return repeat;
  }

  void _normalize({String? keepId}) {
    _order = List<int>.generate(_items.length, (i) => i);
    if (shuffle && _order.length > 1) {
      _order.shuffle();
      if (keepId != null) {
        final idx = _items.indexWhere((e) => e.queueId == keepId);
        if (idx >= 0) {
          _order.remove(idx);
          _order.insert(0, idx);
        }
      }
    }
    _pos = -1;
    if (_items.isNotEmpty) {
      var p = 0;
      if (keepId != null) {
        final idx = _items.indexWhere((e) => e.queueId == keepId);
        if (idx >= 0) p = _order.indexOf(idx);
      }
      _pos = p < 0 ? 0 : p;
    }
  }
}
