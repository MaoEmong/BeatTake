import 'dart:async';

import 'package:flutter/material.dart';

import 'copy.dart';
import 'recording_store.dart';
import 'song_store.dart';
import 'studio_player.dart';
import 'studio_widgets.dart';
import 'track_editor_page.dart';

class SongsPage extends StatefulWidget {
  const SongsPage({super.key, required this.recordings});

  final RecordingStore recordings;

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  final _player = StudioPlayer();
  late final _store = SongStore(widget.recordings.directory);
  List<SavedSong> _songs = [];
  List<SavedRecording> _clips = [];
  bool _busy = true;
  L? _error;

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
      final songs = await _store.list();
      final clips = await widget.recordings.listClips();
      if (mounted) {
        setState(() {
          _songs = songs;
          _clips = clips;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = L.songLoadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([SavedSong? song]) async {
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TrackEditorPage(store: _store, clips: _clips, song: song),
        ),
      );
      if (mounted && saved == true) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = L.songLoadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _play(SavedSong song) async {
    setState(() => _error = null);
    try {
      await _player.toggleSong(song.id, song.placements, {
        for (final clip in _clips) clip.id: clip.file.path,
      });
    } catch (_) {
      if (mounted) setState(() => _error = L.songPlayFailed);
    }
  }

  Future<void> _delete(SavedSong song) async {
    setState(() => _busy = true);
    try {
      if (!await confirmDelete(context, L.deleteSongConfirm, song.name) ||
          !mounted) {
        return;
      }
      if (_player.playing == song.id) await _player.stop();
      await _store.delete(song);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _error = L.removeError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _player,
    builder: (context, _) {
      final enabled = !_busy && !_player.busy;
      return StudioList(
        title: L.songs(context),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: enabled ? _edit : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(L.makeSong(context)),
            ),
          ),
          const SizedBox(height: 12),
          if (!enabled) const LinearProgressIndicator(),
          if (_error case final message?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(liveRegion: true, child: Text(message(context))),
            ),
            if (message == L.songLoadFailed)
              OutlinedButton(
                onPressed: enabled ? _load : null,
                child: Text(L.tryAgain(context)),
              ),
          ],
          if (enabled && _error == null && _songs.isEmpty)
            StudioPanel(child: Text(L.emptySongs(context))),
          for (final song in _songs) ...[
            StudioPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.only(left: 10, right: 2),
                leading: const Icon(Icons.graphic_eq, color: studioAccent),
                title: Text(
                  song.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  L.placementCount(context, song.placements.length),
                ),
                onTap: enabled ? () => _edit(song) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: (_player.playing == song.id
                          ? L.stopPlayback
                          : L.play)(context),
                      onPressed: enabled && song.placements.isNotEmpty
                          ? () => _play(song)
                          : null,
                      icon: Icon(
                        _player.playing == song.id
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    PopupMenuButton<bool>(
                      enabled: enabled,
                      onSelected: (remove) =>
                          remove ? _delete(song) : _edit(song),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: false,
                          child: Text(L.editSong(context)),
                        ),
                        PopupMenuItem(
                          value: true,
                          child: Text(L.deleteSong(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      );
    },
  );
}
