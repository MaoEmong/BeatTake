import 'dart:async';

import 'package:flutter/material.dart';

import 'app_preferences.dart';
import 'copy.dart';
import 'studio_widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.preferences,
    required this.store,
    required this.onChanged,
  });

  final AppPreferences preferences;
  final PreferenceStore store;
  final ValueChanged<AppPreferences> onChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _input = TextEditingController();
  bool _changingPreferences = false;
  bool _changingKey = true;
  bool _hasKey = false;
  L? _settingsError;
  L? _keyMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadKey());
  }

  Future<void> _loadKey() async {
    try {
      final key = await widget.store.readGeminiKey();
      if (mounted) setState(() => _hasKey = key?.isNotEmpty == true);
    } catch (_) {
      if (mounted) setState(() => _keyMessage = L.keyLoadFailed);
    } finally {
      if (mounted) setState(() => _changingKey = false);
    }
  }

  Future<void> _setPreferences(AppPreferences preferences) async {
    if (_changingPreferences) return;
    final update = widget.onChanged;
    setState(() {
      _changingPreferences = true;
      _settingsError = null;
    });
    try {
      await widget.store.save(preferences);
      update(preferences);
    } catch (_) {
      if (mounted) setState(() => _settingsError = L.settingsFailed);
    } finally {
      if (mounted) setState(() => _changingPreferences = false);
    }
  }

  Future<void> _setKey({bool remove = false}) async {
    if (_changingKey) return;
    final key = _input.text.trim();
    if (!remove && (key.isEmpty || RegExp(r'\s').hasMatch(key))) {
      setState(() => _keyMessage = L.keyInvalid);
      return;
    }
    setState(() {
      _changingKey = true;
      _keyMessage = null;
    });
    try {
      await widget.store.saveGeminiKey(remove ? null : key);
      if (mounted) {
        _input.clear();
        setState(() {
          _hasKey = !remove;
          _keyMessage = remove ? L.keyRemoved : L.keySaved;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _keyMessage = L.keyChangeFailed);
    } finally {
      if (mounted) setState(() => _changingKey = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleMedium;
    final preferences = widget.preferences;
    return StudioList(
      title: L.settings(context),
      children: [
        StudioPanel(
          child: DropdownButtonFormField<AppLanguage>(
            // Reset the form field to the persisted language if writing fails.
            key: ValueKey((preferences.language, _changingPreferences)),
            initialValue: preferences.language,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: L.language(context),
              prefixIcon: const Icon(Icons.language),
            ),
            items: [
              for (final language in AppLanguage.values)
                DropdownMenuItem(value: language, child: Text(language.label)),
            ],
            onChanged: _changingPreferences
                ? null
                : (value) {
                    if (value != null) {
                      unawaited(
                        _setPreferences(preferences.copyWith(language: value)),
                      );
                    }
                  },
          ),
        ),
        const SizedBox(height: 12),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L.recordSection(context), style: heading),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(L.autoEdit(context)),
                subtitle: Text(L.autoEditHelp(context)),
                value: preferences.openEditor,
                onChanged: _changingPreferences
                    ? null
                    : (value) => _setPreferences(
                        preferences.copyWith(openEditor: value),
                      ),
              ),
            ],
          ),
        ),
        if (_settingsError case final message?) Text(message(context)),
        const SizedBox(height: 12),
        StudioPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(L.ai(context), style: heading),
              const SizedBox(height: 6),
              Text((_hasKey ? L.keyReady : L.keyHelp)(context)),
              const SizedBox(height: 12),
              TextField(
                controller: _input,
                enabled: !_changingKey,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(labelText: L.gemini(context)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed: _changingKey ? null : _setKey,
                    child: Text(L.saveKey(context)),
                  ),
                  if (_hasKey)
                    TextButton(
                      onPressed: _changingKey
                          ? null
                          : () => _setKey(remove: true),
                      child: Text(L.removeKey(context)),
                    ),
                ],
              ),
              if (_changingKey) const LinearProgressIndicator(),
              if (_keyMessage case final message?)
                Semantics(liveRegion: true, child: Text(message(context))),
            ],
          ),
        ),
      ],
    );
  }
}
