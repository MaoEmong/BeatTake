import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ai_arranger.dart';
import 'app_preferences.dart';
import 'clip_catalog.dart';
import 'copy.dart';
import 'recording_store.dart';
import 'song_store.dart';
import 'studio_widgets.dart';
import 'track_editor_page.dart';

class AiStudioPage extends StatefulWidget {
  const AiStudioPage({
    super.key,
    required this.store,
    required this.preferences,
    required this.openSettings,
    required this.onSaved,
  });

  final RecordingStore store;
  final PreferenceStore preferences;
  final VoidCallback openSettings;
  final VoidCallback onSaved;

  @override
  State<AiStudioPage> createState() => _AiStudioPageState();
}

class _AiStudioPageState extends State<AiStudioPage> {
  final _direction = TextEditingController();
  final _selected = <String>{};
  List<SavedRecording> _clips = [];
  bool _loading = true;
  bool _busy = false;
  bool _hasKey = false;
  L? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final clips = await widget.store.listClips();
      if (!mounted) return;
      setState(() => _clips = clips);
    } catch (_) {
      if (mounted) setState(() => _error = L.storageError);
    }
    try {
      final key = await widget.preferences.readGeminiKey();
      if (mounted) setState(() => _hasKey = key?.isNotEmpty == true);
    } catch (_) {
      if (mounted) setState(() => _error ??= L.keyLoadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _generate() async {
    if (_busy || _selected.isEmpty || !_hasKey) return;
    final names = clipNames(context, _clips);
    final request = _direction.text.trim();
    final paths = {
      for (final clip in _clips)
        if (_selected.contains(clip.id)) clip.id: clip.file.path,
    };
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await widget.preferences.readGeminiKey();
      if (!mounted) return;
      if (key == null || key.isEmpty) {
        setState(() {
          _hasKey = false;
          _error = L.aiNoKey;
        });
        return;
      }
      final details = await compute(inspectClips, paths);
      if (!mounted) return;
      if (details.length != paths.length) {
        setState(() => _error = L.soundOpenFailed);
        return;
      }
      final placements = await AiArranger().arrange(
        key: key,
        request: request,
        sounds: [
          for (final entry in details.entries)
            (
              clipId: entry.key,
              name: names[entry.key]!,
              durationMs: entry.value.durationMs,
            ),
        ],
      );
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TrackEditorPage(
            clips: _clips,
            store: SongStore(widget.store.directory),
            arrangement: placements,
          ),
        ),
      );
      if (mounted && saved == true) widget.onSaved();
    } on ArrangementException catch (error) {
      if (mounted) {
        setState(
          () => _error = switch (error.reason) {
            ArrangementFailure.selection => L.aiSelection,
            ArrangementFailure.invalidResult => L.aiInvalidResult,
            ArrangementFailure.timeout => L.aiTimeout,
            ArrangementFailure.connection => L.aiConnection,
            ArrangementFailure.access => L.aiAccess,
            ArrangementFailure.quota => L.aiQuota,
            ArrangementFailure.unavailable => L.aiUnavailable,
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = L.keyLoadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _direction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = clipNames(context, _clips);
    return StudioList(
      title: L.makeAiSong(context),
      children: [
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                L.chooseSounds(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(L.aiHelp(context)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_loading || _busy) const LinearProgressIndicator(),
        if (!_loading && !_hasKey) ...[
          Text(L.aiNoKey(context)),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: widget.openSettings,
            icon: const Icon(Icons.settings_outlined),
            label: Text(L.settings(context)),
          ),
          const SizedBox(height: 12),
        ],
        if (_error case final message?) ...[
          Semantics(liveRegion: true, child: Text(message(context))),
          if (message == L.storageError)
            OutlinedButton(
              onPressed: _loading ? null : _load,
              child: Text(L.tryAgain(context)),
            ),
          const SizedBox(height: 12),
        ],
        if (!_loading && names.isEmpty)
          StudioPanel(child: Text(L.emptyClips(context))),
        if (names.isNotEmpty) ...[
          StudioPanel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final entry in names.entries)
                  CheckboxListTile(
                    title: Text(entry.value),
                    value: _selected.contains(entry.key),
                    onChanged:
                        !_busy &&
                            (_selected.length < AiArranger.maxSounds ||
                                _selected.contains(entry.key))
                        ? (selected) {
                            setState(() {
                              if (selected == true) {
                                _selected.add(entry.key);
                              } else {
                                _selected.remove(entry.key);
                              }
                              _error = null;
                            });
                          }
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _direction,
            enabled: !_busy,
            maxLength: 120,
            decoration: InputDecoration(labelText: L.mood(context)),
          ),
          FilledButton.icon(
            onPressed: !_busy && !_loading && _hasKey && _selected.isNotEmpty
                ? _generate
                : null,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: Text((_busy ? L.arranging : L.generate)(context)),
          ),
        ],
      ],
    );
  }
}
