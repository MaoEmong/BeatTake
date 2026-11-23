import 'dart:async';

import 'package:flutter/material.dart';

import 'recording_store.dart';
import 'song_store.dart';
import 'track_editor_page.dart';

class SongsPage extends StatefulWidget {
  const SongsPage({super.key, required this.store, required this.clips});

  final SongStore store;
  final List<SavedRecording> clips;

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  List<SavedSong> _songs = [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final songs = await widget.store.list();
      if (mounted) setState(() => _songs = songs);
    } catch (_) {
      if (mounted) setState(() => _error = '곡 목록을 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([SavedSong? song]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TrackEditorPage(
          clips: widget.clips,
          store: widget.store,
          song: song,
        ),
      ),
    );
    if (mounted && saved == true) await _load();
  }

  Future<void> _delete(SavedSong song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('곡을 삭제할까요?'),
        content: Text(song.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) return;
    setState(() => _busy = true);
    try {
      await widget.store.delete(song);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '곡을 삭제하지 못했어요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 곡')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _busy ? null : _edit,
              icon: const Icon(Icons.add),
              label: const Text('새 곡 만들기'),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error case final message?) Text(message),
          if (!_busy && _error == null && _songs.isEmpty)
            const Text('저장한 곡이 여기에 표시돼요.'),
          for (final song in _songs)
            ListTile(
              title: Text(song.name),
              subtitle: Text('소리 ${song.placements.length}개'),
              onTap: _busy ? null : () => _edit(song),
              trailing: IconButton(
                tooltip: '곡 삭제',
                onPressed: _busy ? null : () => _delete(song),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
        ],
      ),
    );
  }
}
