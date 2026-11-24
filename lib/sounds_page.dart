import 'dart:async';

import 'package:flutter/material.dart';

import 'clip_editor_page.dart';
import 'copy.dart';
import 'recording_store.dart';
import 'studio_player.dart';
import 'studio_widgets.dart';

enum SoundTab { originals, clips }

class SoundsPage extends StatefulWidget {
  const SoundsPage({super.key, required this.store, required this.initialTab});

  final RecordingStore store;
  final SoundTab initialTab;

  @override
  State<SoundsPage> createState() => _SoundsPageState();
}

class _SoundsPageState extends State<SoundsPage> {
  final _player = StudioPlayer();
  late SoundTab _tab = widget.initialTab;
  List<SavedRecording> _originals = [];
  List<SavedRecording> _clips = [];
  bool _busy = true;
  L? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final originals = await widget.store.list();
      final clips = await widget.store.listClips();
      if (mounted) {
        setState(() {
          _originals = originals;
          _clips = clips;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = L.storageError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _play(SavedRecording sound) async {
    setState(() => _message = null);
    try {
      await _player.toggleFile(sound.key, widget.store.files);
    } catch (_) {
      if (mounted) setState(() => _message = L.soundPlayFailed);
    }
  }

  Future<void> _edit(SavedRecording sound) async {
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ClipEditorPage(recording: sound, store: widget.store),
        ),
      );
      if (mounted && saved == true) {
        _tab = SoundTab.clips;
        await _load();
      }
    } catch (_) {
      if (mounted) setState(() => _message = L.soundOpenFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(SavedRecording sound, {required bool edited}) async {
    setState(() => _busy = true);
    try {
      if (!await confirmDelete(context, L.removeSoundConfirm, sound.name) ||
          !mounted) {
        return;
      }
      if (_player.playing == sound.key) await _player.stop();
      await widget.store.delete(sound, edited: edited);
      if (mounted) {
        setState(() {
          (edited ? _clips : _originals).remove(sound);
          _message = null;
        });
      }
    } on ClipInUse {
      if (mounted) setState(() => _message = L.inUse);
    } catch (_) {
      if (mounted) setState(() => _message = L.removeError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeTab(SoundTab value) async {
    if (_tab == value) return;
    setState(() => _busy = true);
    try {
      await _player.stop();
      if (mounted) {
        setState(() {
          _tab = value;
          _message = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = L.soundPlayFailed);
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
      final edited = _tab == SoundTab.clips;
      final sounds = edited ? _clips : _originals;
      final active = !_busy && !_player.busy;
      return StudioList(
        title: L.sounds(context),
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final (tab, label) in [
                (SoundTab.originals, L.originals),
                (SoundTab.clips, L.clips),
              ])
                ChoiceChip(
                  label: Text(label(context)),
                  selected: _tab == tab,
                  onSelected: active ? (_) => _changeTab(tab) : null,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy || _player.busy) const LinearProgressIndicator(),
          if (_message case final message?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Semantics(liveRegion: true, child: Text(message(context))),
            ),
            if (message == L.storageError)
              OutlinedButton(
                onPressed: _busy ? null : _load,
                child: Text(L.tryAgain(context)),
              ),
          ],
          if (sounds.isEmpty && active && _message == null)
            StudioPanel(
              child: Text((edited ? L.emptyClips : L.emptyRecordings)(context)),
            ),
          for (final (index, sound) in sounds.indexed) ...[
            const SizedBox(height: 8),
            StudioPanel(
              padding: EdgeInsets.zero,
              child: ListTile(
                key: ValueKey(sound.id),
                contentPadding: const EdgeInsets.only(left: 10, right: 2),
                title: Text(
                  sound.name ??
                      (edited ? L.clipName : L.recordName)(
                        context,
                        sounds.length - index,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  MaterialLocalizations.of(
                    context,
                  ).formatMediumDate(sound.recordedAt),
                ),
                onTap: active ? () => _edit(sound) : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: (_player.playing == sound.key
                          ? L.stopPlayback
                          : L.play)(context),
                      onPressed: active ? () => _play(sound) : null,
                      icon: Icon(
                        _player.playing == sound.key
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    PopupMenuButton<bool>(
                      enabled: active,
                      onSelected: (remove) => remove
                          ? _remove(sound, edited: edited)
                          : _edit(sound),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: false,
                          child: Text(L.editSound(context)),
                        ),
                        PopupMenuItem(
                          value: true,
                          child: Text(L.removeSound(context)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}
