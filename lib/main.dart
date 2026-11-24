import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'ai_arranger.dart';
import 'ai_provider.dart';
import 'ai_studio_page.dart';
import 'app_preferences.dart';
import 'copy.dart';
import 'recorder_page.dart';
import 'recording_store.dart';
import 'settings_page.dart';
import 'song_store.dart';
import 'songs_page.dart';
import 'sounds_page.dart';
import 'studio_widgets.dart';
import 'track_editor_page.dart';

void main() => runApp(const BeatTakeApp());

class BeatTakeApp extends StatefulWidget {
  const BeatTakeApp({
    super.key,
    this.openRecordings = RecordingStore.open,
    this.arrangerFor = AiArranger.new,
  });

  final Future<RecordingStore> Function() openRecordings;
  final AiArranger Function(AiProvider) arrangerFor;

  @override
  State<BeatTakeApp> createState() => _BeatTakeAppState();
}

class _BeatTakeAppState extends State<BeatTakeApp> {
  final _store = const PreferenceStore();
  AppPreferences? _preferences;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final preferences = await _store.load();
      if (mounted) setState(() => _preferences = preferences);
    } catch (_) {
      if (mounted) setState(() => _preferences = const AppPreferences());
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = _preferences;
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: studioTheme,
      locale: (preferences?.language ?? AppLanguage.en).locale,
      supportedLocales: AppLanguage.values.map((language) => language.locale),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: preferences == null
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _StudioShell(
              openRecordings: widget.openRecordings,
              arrangerFor: widget.arrangerFor,
              preferences: preferences,
              preferenceStore: _store,
              onPreferencesChanged: (value) {
                if (mounted) setState(() => _preferences = value);
              },
            ),
    );
  }
}

enum _Section {
  home(L.home, Icons.home_outlined, Icons.home_rounded),
  sounds(L.sounds, Icons.graphic_eq, Icons.graphic_eq),
  songs(L.songs, Icons.library_music_outlined, Icons.library_music_rounded),
  ai(L.ai, Icons.auto_awesome_outlined, Icons.auto_awesome_rounded),
  settings(L.settings, Icons.settings_outlined, Icons.settings_rounded);

  const _Section(this.label, this.icon, this.selectedIcon);

  final L label;
  final IconData icon;
  final IconData selectedIcon;
}

class _StudioShell extends StatefulWidget {
  const _StudioShell({
    required this.openRecordings,
    required this.arrangerFor,
    required this.preferences,
    required this.preferenceStore,
    required this.onPreferencesChanged,
  });

  final Future<RecordingStore> Function() openRecordings;
  final AiArranger Function(AiProvider) arrangerFor;
  final AppPreferences preferences;
  final PreferenceStore preferenceStore;
  final ValueChanged<AppPreferences> onPreferencesChanged;

  @override
  State<_StudioShell> createState() => _StudioShellState();
}

class _StudioShellState extends State<_StudioShell> {
  late Future<RecordingStore> _library = widget.openRecordings();
  _Section _selected = _Section.home;
  SoundTab _tab = SoundTab.originals;
  bool _openingSong = false;
  L? _homeError;

  void _select(_Section section) => setState(() => _selected = section);

  Future<void> _record(RecordingStore store) async {
    final tab = await Navigator.push<SoundTab>(
      context,
      MaterialPageRoute(
        builder: (_) => RecorderPage(
          store: store,
          openEditor: widget.preferences.openEditor,
        ),
      ),
    );
    if (mounted && tab != null) {
      setState(() {
        _tab = tab;
        _selected = _Section.sounds;
      });
    }
  }

  Future<void> _makeSong(RecordingStore store) async {
    if (_openingSong) return;
    setState(() {
      _openingSong = true;
      _homeError = null;
    });
    try {
      final clips = await store.listClips();
      if (!mounted || _selected != _Section.home) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              TrackEditorPage(clips: clips, store: SongStore(store.directory)),
        ),
      );
      if (mounted && saved == true) _select(_Section.songs);
    } catch (_) {
      if (mounted) setState(() => _homeError = L.storageError);
    } finally {
      if (mounted) setState(() => _openingSong = false);
    }
  }

  Widget _content() {
    if (_selected == _Section.settings) {
      return SettingsPage(
        preferences: widget.preferences,
        store: widget.preferenceStore,
        onChanged: widget.onPreferencesChanged,
      );
    }
    return FutureBuilder<RecordingStore>(
      future: _library,
      builder: (context, snapshot) {
        final store = snapshot.data;
        if (store == null) {
          if (!snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          return StudioList(
            title: _selected.label(context),
            children: [
              StudioPanel(child: Text(L.storageError(context))),
              OutlinedButton(
                onPressed: () =>
                    setState(() => _library = widget.openRecordings()),
                child: Text(L.tryAgain(context)),
              ),
            ],
          );
        }
        return switch (_selected) {
          _Section.home => _Home(
            onRecord: () => _record(store),
            onMake: _openingSong ? null : () => _makeSong(store),
            onAi: () => _select(_Section.ai),
            error: _homeError,
          ),
          _Section.sounds => SoundsPage(store: store, initialTab: _tab),
          _Section.songs => SongsPage(recordings: store),
          _Section.ai => AiStudioPage(
            key: ValueKey(widget.preferences.aiProvider),
            store: store,
            preferences: widget.preferenceStore,
            arranger: widget.arrangerFor(widget.preferences.aiProvider),
            openSettings: () => _select(_Section.settings),
            onSaved: () => _select(_Section.songs),
          ),
          _Section.settings => const SizedBox.shrink(),
        };
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width >= 700 ? 100 : 72,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xff1d221e),
                border: Border(right: BorderSide(color: studioBorder)),
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                children: [
                  const ExcludeSemantics(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'b.',
                          style: TextStyle(
                            color: studioAccent,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  for (final section in _Section.values)
                    _RailButton(
                      section: section,
                      selected: section == _selected,
                      onPressed: () => _select(section),
                    ),
                ],
              ),
            ),
          ),
          Expanded(child: _content()),
        ],
      ),
    ),
  );
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.section,
    required this.selected,
    required this.onPressed,
  });

  final _Section section;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = section.label(context);
    final textColor = selected
        ? studioAccent
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: selected ? const Color(0xff293623) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onPressed,
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 61),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? section.selectedIcon : section.icon,
                        size: 22,
                        color: textColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
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

class _Home extends StatelessWidget {
  const _Home({
    required this.onRecord,
    required this.onMake,
    required this.onAi,
    required this.error,
  });

  final VoidCallback onRecord;
  final VoidCallback? onMake;
  final VoidCallback onAi;
  final L? error;

  static const _mark = [
    .15,
    .28,
    .19,
    .43,
    .37,
    .63,
    .84,
    .52,
    .29,
    .41,
    .66,
    .86,
    .53,
    .32,
    .62,
    .37,
    .23,
    .14,
    .22,
    .11,
  ];

  @override
  Widget build(BuildContext context) {
    final type = Theme.of(context).textTheme;
    return StudioList(
      children: [
        const SizedBox(height: 8),
        const Text(
          appName,
          style: TextStyle(
            fontSize: 40,
            height: .97,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(L.homeIntro(context), style: type.bodyMedium),
        const SizedBox(height: 22),
        Semantics(
          button: true,
          label: L.recordSound(context),
          child: Material(
            color: studioAccent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onRecord,
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(
                          Icons.mic_rounded,
                          color: Color(0xff202a19),
                          size: 23,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        L.recordSound(context),
                        style: type.headlineSmall?.copyWith(
                          color: const Color(0xff202a19),
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        L.homeRecordHelp(context),
                        style: const TextStyle(
                          color: Color(0xff34432a),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Waveform(
                        levels: _mark,
                        height: 34,
                        color: Color(0xff526740),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _HomeAction(
          icon: Icons.library_music_outlined,
          label: L.makeSong(context),
          detail: L.homeSongHelp(context),
          onTap: onMake,
        ),
        const SizedBox(height: 8),
        _HomeAction(
          icon: Icons.auto_awesome_outlined,
          label: L.makeAiSong(context),
          detail: L.homeAiHelp(context),
          onTap: onAi,
        ),
        if (error case final message?)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(message(context)),
          ),
        const SizedBox(height: 20),
        Text(
          L.forgeCredit(context),
          style: type.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => StudioPanel(
    padding: EdgeInsets.zero,
    child: ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      leading: Icon(icon, color: studioAccent),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detail),
      trailing: const Icon(Icons.north_east, size: 16),
    ),
  );
}
