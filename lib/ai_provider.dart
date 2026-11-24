enum AiProvider {
  gemini('Gemini'),
  claude('Claude'),
  openai('OpenAI');

  const AiProvider(this.label);

  final String label;

  static AiProvider fromCode(Object? code) => switch (code) {
    'claude' => claude,
    'openai' => openai,
    _ => gemini,
  };
}
