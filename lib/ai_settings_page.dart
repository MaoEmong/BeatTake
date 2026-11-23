import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _keyName = 'gemini_api_key';

  static Future<String?> readKey() => _storage.read(key: _keyName);

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _input = TextEditingController();
  bool _busy = true;
  bool _hasKey = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final key = await AiSettingsPage.readKey();
      if (mounted) setState(() => _hasKey = key != null && key.isNotEmpty);
    } catch (_) {
      if (mounted) setState(() => _message = '등록한 키를 확인하지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _update({required bool remove}) async {
    final text = _input.text.trim();
    if (!remove && (text.isEmpty || RegExp(r'\s').hasMatch(text))) {
      setState(() => _message = '공백 없이 Gemini API 키를 입력해 주세요.');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (remove) {
        await AiSettingsPage._storage.delete(key: AiSettingsPage._keyName);
      } else {
        await AiSettingsPage._storage.write(
          key: AiSettingsPage._keyName,
          value: text,
        );
      }
      if (mounted) {
        _input.clear();
        setState(() {
          _hasKey = !remove;
          _message = remove ? '이 기기에서 키를 지웠어요.' : '이 기기에 키를 저장했어요.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = '이 기기의 키 설정을 변경하지 못했어요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 설정')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _hasKey ? 'Gemini 키가 등록돼 있어요.' : 'AI 편곡에 사용할 개인 Gemini 키를 등록해 주세요.',
          ),
          TextField(
            controller: _input,
            enabled: !_busy,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Gemini API 키'),
          ),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _update(remove: false),
                child: const Text('키 저장'),
              ),
              if (_hasKey)
                TextButton(
                  onPressed: _busy ? null : () => _update(remove: true),
                  child: const Text('키 지우기'),
                ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_message case final message?) Text(message),
        ],
      ),
    );
  }
}
