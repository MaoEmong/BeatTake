import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'clip_catalog.dart';
import 'copy.dart';
import 'recording_store.dart';
import 'song.dart';
import 'song_store.dart';
import 'studio_player.dart';
import 'studio_widgets.dart';

class TrackEditorPage extends StatefulWidget {
  const TrackEditorPage({
    super.key,
    required this.clips,
    required this.store,
    this.song,
    this.arrangement = const [],
  });

  final List<SavedRecording> clips;
  final SongStore store;
  final SavedSong? song;
  final List<SoundPlacement> arrangement;

  @override
  State<TrackEditorPage> createState() => _TrackEditorPageState();
}

class _TrackEditorPageState extends State<TrackEditorPage> {
  final _player = StudioPlayer();
  late final List<SoundPlacement> _placements;
  late final TextEditingController _name;
  late final Map<String, String> _keys;
  Map<String, ClipDetails>? _details;
  int _track = 0;
  int? _focus;
  bool _saving = false;
  L? _error;

  @override
  void initState() {
    super.initState();
    _placements = [...(widget.song?.placements ?? widget.arrangement)];
    if (_placements.isNotEmpty) _track = _placements.first.track;
    _name = TextEditingController(text: widget.song?.name ?? '');
    _keys = {for (final clip in widget.clips) clip.id: clip.key};
    unawaited(_loadDetails());
  }

  Future<void> _loadDetails() async {
    try {
      final details = await inspectClips(_keys, widget.store.files);
      if (mounted) setState(() => _details = details);
    } catch (_) {
      if (mounted) {
        setState(() {
          _details = {};
          _error = L.soundOpenFailed;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _player.busy || _player.playing != null) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = L.songNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.save(
        id: widget.song?.id,
        name: name,
        placements: _placements,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = L.songSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _play() async {
    setState(() => _error = null);
    try {
      await _player.toggleSong(
        'editor',
        List.of(_placements),
        _keys,
        widget.store.files,
      );
    } catch (_) {
      if (mounted) setState(() => _error = L.songPlayFailed);
    }
  }

  void _selectTrack(int track) => setState(() {
    _track = track;
    _focus = null;
  });

  Future<void> _changePlacement(Map<String, String> names, [int? index]) async {
    final details = _details ?? {};
    final existing = index == null ? null : _placements[index];
    final available = {
      for (final entry in names.entries)
        if (details.containsKey(entry.key)) entry.key: entry.value,
    };
    if (available.isEmpty) return;
    FocusScope.of(context).unfocus();
    final placement = await showDialog<SoundPlacement>(
      context: context,
      builder: (_) => _PlacementDialog(
        names: available,
        details: details,
        selectedTrack: _track,
        existing: existing,
      ),
    );
    if (!mounted || placement == null) return;
    setState(() {
      _track = placement.track;
      _error = null;
      if (index == null) {
        _focus = _placements.length;
        _placements.add(placement);
      } else {
        _placements[index] = placement;
        _focus = index;
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _player,
    builder: (context, _) {
      final names = clipNames(context, widget.clips);
      final details = _details ?? {};
      final tracks = <int>{
        0,
        1,
        2,
        _track,
        ..._placements.map((p) => p.track),
      }.toList()..sort();
      final indices =
          [
            for (final (index, placement) in _placements.indexed)
              if (placement.track == _track) index,
          ]..sort(
            (a, b) => _placements[a].startMs.compareTo(_placements[b].startMs),
          );
      final focus = indices.contains(_focus) ? _focus : indices.firstOrNull;
      final selected = focus == null ? null : _placements[focus];
      final busy = _saving || _player.busy;
      final canEdit = !busy && _player.playing == null;
      final anyClips = details.isNotEmpty;
      final duration = _placements.fold<int>(
        0,
        (total, p) =>
            math.max(total, p.startMs + (details[p.clipId]?.durationMs ?? 0)),
      );
      return PopScope<bool>(
        canPop: !busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(L.makeSong(context)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton(
                  onPressed: canEdit ? _save : null,
                  child: Text(L.save(context)),
                ),
              ),
            ],
          ),
          body: StudioList(
            children: [
              TextField(
                controller: _name,
                enabled: canEdit,
                maxLength: 40,
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(labelText: L.songName(context)),
              ),
              const SizedBox(height: 10),
              StudioPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            L.overview(context),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Text(timeCode(Duration(milliseconds: duration))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Overview(
                      tracks: tracks,
                      placements: _placements,
                      details: details,
                      selected: _track,
                      extentMs: math.max(4000, duration),
                      positionMs: _player.playing == null
                          ? null
                          : _player.position.inMilliseconds,
                      onSelect: _selectTrack,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final track in tracks)
                    ChoiceChip(
                      label: Text(L.track(context, track + 1)),
                      selected: track == _track,
                      onSelected: (_) => _selectTrack(track),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (selected == null)
                StudioPanel(child: Text(L.emptyTrack(context)))
              else
                StudioPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              names[selected.clipId] ?? L.missingSound(context),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: canEdit && anyClips
                                ? () => _changePlacement(names, focus)
                                : null,
                            tooltip: L.editPlacement(context),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Waveform(
                        levels: details[selected.clipId]?.peaks ?? [],
                        height: 110,
                        color: trackColors[_track],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          L.startsAt(
                            context,
                            (selected.startMs / 1000).toStringAsFixed(2),
                          ),
                          if (details[selected.clipId] case final detail?)
                            L.seconds(
                              context,
                              (detail.durationMs / 1000).toStringAsFixed(2),
                            ),
                        ].join('   ·   '),
                      ),
                    ],
                  ),
                ),
              if (indices.isNotEmpty) const SizedBox(height: 8),
              for (final index in indices)
                ListTile(
                  dense: true,
                  selected: index == focus,
                  contentPadding: const EdgeInsets.only(left: 10),
                  title: Text(
                    names[_placements[index].clipId] ?? L.missingSound(context),
                  ),
                  subtitle: Text(
                    L.startsAt(
                      context,
                      (_placements[index].startMs / 1000).toStringAsFixed(2),
                    ),
                  ),
                  onTap: () => setState(() => _focus = index),
                  trailing: IconButton(
                    tooltip: L.removePlacement(context),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: canEdit
                        ? () => setState(() {
                            _placements.removeAt(index);
                            _focus = null;
                          })
                        : null,
                  ),
                ),
              if (_details == null || busy) const LinearProgressIndicator(),
              if (_details != null && !anyClips && _placements.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(L.emptyClips(context)),
                ),
              if (_error case final message?)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(message(context)),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                6,
                14,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  IconButton.filled(
                    onPressed: !busy && _placements.isNotEmpty ? _play : null,
                    tooltip: (_player.playing == null
                        ? L.play
                        : L.stopPlayback)(context),
                    icon: Icon(
                      _player.playing == null
                          ? Icons.play_arrow_rounded
                          : Icons.stop_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timeCode(_player.position),
                      style: const TextStyle(
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed:
                        canEdit &&
                            anyClips &&
                            _placements.length < SoundPlacement.maxCount
                        ? () => _changePlacement(names)
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(L.addSound(context)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.tracks,
    required this.placements,
    required this.details,
    required this.selected,
    required this.extentMs,
    required this.positionMs,
    required this.onSelect,
  });

  final List<int> tracks;
  final List<SoundPlacement> placements;
  final Map<String, ClipDetails> details;
  final int selected;
  final int extentMs;
  final int? positionMs;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final track in tracks)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: track == selected
                ? trackColors[track].withValues(alpha: .09)
                : studioBackground,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: () => onSelect(track),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        L.track(context, track + 1),
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 29,
                      child: LayoutBuilder(
                        builder: (_, constraints) {
                          final width = constraints.maxWidth;
                          return Stack(
                            clipBehavior: Clip.hardEdge,
                            children: [
                              for (final fraction in [.25, .5, .75])
                                Positioned(
                                  left: width * fraction,
                                  top: 0,
                                  bottom: 0,
                                  child: const ColoredBox(
                                    color: studioBorder,
                                    child: SizedBox(width: 1),
                                  ),
                                ),
                              for (final placement in placements.where(
                                (p) => p.track == track,
                              ))
                                Positioned(
                                  left: width * placement.startMs / extentMs,
                                  top: 4,
                                  bottom: 4,
                                  width: math.max(
                                    3,
                                    width *
                                        (details[placement.clipId]
                                                ?.durationMs ??
                                            100) /
                                        extentMs,
                                  ),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: trackColors[track],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRect(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Waveform(
                                          levels:
                                              details[placement.clipId]
                                                  ?.peaks ??
                                              [],
                                          color: studioBackground,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (positionMs case final position?)
                                Positioned(
                                  left:
                                      width *
                                      (position / extentMs).clamp(0.0, 1.0),
                                  top: 0,
                                  bottom: 0,
                                  child: const ColoredBox(
                                    color: Colors.white,
                                    child: SizedBox(width: 1.5),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
}

class _PlacementDialog extends StatefulWidget {
  const _PlacementDialog({
    required this.names,
    required this.details,
    required this.selectedTrack,
    required this.existing,
  });

  final Map<String, String> names;
  final Map<String, ClipDetails> details;
  final int selectedTrack;
  final SoundPlacement? existing;

  @override
  State<_PlacementDialog> createState() => _PlacementDialogState();
}

class _PlacementDialogState extends State<_PlacementDialog> {
  late String _clip = widget.names.containsKey(widget.existing?.clipId)
      ? widget.existing!.clipId
      : widget.names.keys.first;
  late int _track = widget.existing?.track ?? widget.selectedTrack;
  late String _seconds = ((widget.existing?.startMs ?? 0) / 1000).toString();
  L? _error;

  void _confirm() {
    final seconds = double.tryParse(_seconds.trim().replaceAll(',', '.'));
    if (seconds == null ||
        !seconds.isFinite ||
        seconds < 0 ||
        seconds * 1000 > SoundPlacement.maxStartMs) {
      setState(() => _error = L.startRange);
      return;
    }
    final start = (seconds * 1000).round();
    if (start + widget.details[_clip]!.durationMs >
        SoundPlacement.maxStartMs + 1) {
      setState(() => _error = L.songTooLong);
      return;
    }
    Navigator.pop(
      context,
      SoundPlacement(clipId: _clip, track: _track, startMs: start),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      (widget.existing == null ? L.addSound : L.editPlacement)(context),
    ),
    scrollable: true,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: _clip,
          decoration: InputDecoration(labelText: L.clip(context)),
          items: [
            for (final entry in widget.names.entries)
              DropdownMenuItem(
                value: entry.key,
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) {
            if (value != null) _clip = value;
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: _track,
          decoration: InputDecoration(labelText: L.trackLabel(context)),
          items: [
            for (var track = 0; track < SoundPlacement.trackCount; track++)
              DropdownMenuItem(
                value: track,
                child: Text(L.track(context, track + 1)),
              ),
          ],
          onChanged: (value) {
            if (value != null) _track = value;
          },
        ),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: _seconds,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: L.startSeconds(context),
            errorText: _error?.call(context),
            errorMaxLines: 3,
          ),
          onChanged: (text) => _seconds = text,
          onFieldSubmitted: (_) => _confirm(),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(L.cancel(context)),
      ),
      FilledButton(onPressed: _confirm, child: Text(L.apply(context))),
    ],
  );
}
