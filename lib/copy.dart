import 'package:flutter/widgets.dart';

const appName = 'BeatTake';

enum AppLanguage {
  en('English'),
  ko('한국어'),
  ja('日本語'),
  zh('简体中文');

  const AppLanguage(this.label);

  final String label;

  Locale get locale => Locale(name);

  static AppLanguage fromCode(String? code) => switch (code) {
    'ko' => ko,
    'ja' => ja,
    'zh' => zh,
    _ => en,
  };
}

enum L {
  home('Home', '홈', 'ホーム', '首页'),
  sounds('Sounds', '소리 보관함', 'サウンド', '声音库'),
  songs('Songs', '곡 보관함', '曲ライブラリ', '曲库'),
  ai('AI Studio', 'AI 곡 만들기', 'AI 作曲', 'AI 作曲'),
  settings('Settings', '설정', '設定', '设置'),
  language('Language', '언어', '言語', '语言'),
  recordSection('Recording', '녹음', '録音', '录音'),
  autoEdit(
    'Open editor after recording',
    '녹음 후 다듬기 열기',
    '録音後に編集画面を開く',
    '录音后打开编辑器',
  ),
  autoEditHelp(
    'When off, new recordings go straight to Sounds.',
    '끄면 새 녹음이 바로 소리 보관함에 저장됩니다.',
    'オフにすると新しい録音はサウンドに保存されます。',
    '关闭后，新录音将直接保存到声音库。',
  ),
  settingsFailed(
    'Couldn’t save this setting.',
    '설정을 저장하지 못했어요.',
    '設定を保存できませんでした。',
    '无法保存此设置。',
  ),
  gemini('Gemini API key', 'Gemini API 키', 'Gemini API キー', 'Gemini API 密钥'),
  keyHelp(
    'Add your personal key to use AI Studio.',
    'AI로 곡을 만들려면 개인 키를 등록해 주세요.',
    'AI 作曲を使うには個人のキーを登録してください。',
    '使用 AI 作曲前，请添加个人密钥。',
  ),
  keyReady(
    'A key is saved on this device.',
    '이 기기에 키가 저장되어 있어요.',
    'この端末にキーが保存されています。',
    '此设备已保存密钥。',
  ),
  keyLoadFailed(
    'Couldn’t read the saved key.',
    '저장한 키를 읽지 못했어요.',
    '保存したキーを読み込めませんでした。',
    '无法读取保存的密钥。',
  ),
  keyInvalid(
    'Enter your Gemini API key without spaces.',
    '공백 없이 Gemini API 키를 입력해 주세요。',
    '空白を入れずに Gemini API キーを入力してください。',
    '请输入不含空格的 Gemini API 密钥。',
  ),
  keySaved('Key saved.', '키를 저장했어요.', 'キーを保存しました。', '密钥已保存。'),
  keyRemoved('Key removed.', '키를 지웠어요.', 'キーを削除しました。', '密钥已移除。'),
  keyChangeFailed(
    'Couldn’t update the key.',
    '키를 변경하지 못했어요.',
    'キーを変更できませんでした。',
    '无法更新密钥。',
  ),
  saveKey('Save key', '키 저장', 'キーを保存', '保存密钥'),
  removeKey('Remove key', '키 지우기', 'キーを削除', '移除密钥'),
  homeIntro(
    'Make music from the sounds around you.',
    '주변의 소리로 곡을 만들어 보세요.',
    '身の回りの音で曲を作りましょう。',
    '用身边的声音制作音乐。',
  ),
  recordSound('Record a sound', '소리 녹음하기', '音を録音', '录制声音'),
  makeSong('Make a song', '곡 만들기', '曲を作る', '制作歌曲'),
  makeAiSong('Make a song with AI', 'AI로 곡 만들기', 'AI で曲を作る', '用 AI 制作歌曲'),
  homeRecordHelp(
    'Capture a sound to use in a song.',
    '곡에 쓸 소리를 녹음합니다.',
    '曲に使う音を録音します。',
    '录下可以用来制作歌曲的声音。',
  ),
  homeSongHelp(
    'Place your sounds on tracks.',
    '모아 둔 소리를 트랙에 배치합니다.',
    '集めた音をトラックに配置します。',
    '将收集的声音放入音轨。',
  ),
  homeAiHelp(
    'Get an arrangement you can edit.',
    'AI가 제안한 배치를 편집합니다.',
    'AI の提案を編集できます。',
    '获取可编辑的编排方案。',
  ),
  forgeCredit(
    'Built for Vibe Forge by $appName',
    'Vibe Forge를 위해 제작 · $appName',
    '$appName が Vibe Forge 向けに制作',
    '$appName 为 Vibe Forge 制作',
  ),
  storageError(
    'Couldn’t open your sound library.',
    '소리 보관함을 열지 못했어요.',
    'サウンドを開けませんでした。',
    '无法打开声音库。',
  ),
  tryAgain('Try again', '다시 시도', '再試行', '重试'),
  recordTitle('Record', '소리 녹음', '録音', '录音'),
  readyRecord('Ready to record', '녹음할 준비가 됐어요', '録音できます', '准备录音'),
  recordingNow('Recording', '녹음 중', '録音中', '正在录音'),
  startRecording('Start recording', '녹음 시작', '録音を開始', '开始录音'),
  stopRecording('Stop and save', '정지하고 저장', '停止して保存', '停止并保存'),
  saving('Saving…', '저장하는 중…', '保存中…', '正在保存…'),
  micPermission(
    'Allow microphone access in your device settings to record.',
    '녹음하려면 기기 설정에서 마이크 사용을 허용해 주세요.',
    '録音するには端末の設定でマイクを許可してください。',
    '请在设备设置中允许麦克风访问后再录音。',
  ),
  recordStartError(
    'Couldn’t start recording.',
    '녹음을 시작하지 못했어요.',
    '録音を開始できませんでした。',
    '无法开始录音。',
  ),
  recordSaveError(
    'Couldn’t save the recording. Please try recording again.',
    '녹음을 저장하지 못했어요. 다시 녹음해 주세요.',
    '録音を保存できませんでした。もう一度録音してください。',
    '无法保存录音。请重新录制。',
  ),
  recordSaved('Recording saved.', '녹음을 저장했어요.', '録音を保存しました。', '录音已保存。'),
  viewSounds('Open Sounds', '소리 보관함 열기', 'サウンドを開く', '打开声音库'),
  originals('Recordings', '원본 녹음', '元の録音', '原始录音'),
  clips('Edited clips', '다듬은 소리', '編集済みクリップ', '已编辑片段'),
  recordName('Recording {0}', '녹음 {0}', '録音 {0}', '录音 {0}'),
  clipName('Clip {0}', '다듬은 소리 {0}', 'クリップ {0}', '片段 {0}'),
  emptyRecordings(
    'Record a sound to start your library.',
    '소리를 녹음하면 여기에 표시됩니다.',
    '音を録音するとここに表示されます。',
    '录制声音后将在此显示。',
  ),
  emptyClips(
    'Trim and save a recording to use it in a song.',
    '녹음을 다듬어 저장하면 곡에 쓸 수 있어요.',
    '録音を編集して保存すると曲に使えます。',
    '修剪并保存录音后即可用于歌曲。',
  ),
  play('Play', '재생', '再生', '播放'),
  stopPlayback('Stop playback', '재생 정지', '再生を停止', '停止播放'),
  editSound('Edit sound', '소리 다듬기', '音を編集', '编辑声音'),
  removeSound('Delete sound', '소리 삭제', '音を削除', '删除声音'),
  removeSoundConfirm(
    'Delete this sound?',
    '이 소리를 삭제할까요?',
    'この音を削除しますか？',
    '删除此声音？',
  ),
  cancel('Cancel', '취소', 'キャンセル', '取消'),
  remove('Delete', '삭제', '削除', '删除'),
  inUse(
    'Remove this sound from any saved songs before deleting it.',
    '이 소리가 들어 있는 곡에서 배치를 먼저 지워 주세요.',
    'この音を使用している保存済みの曲から先に取り除いてください。',
    '请先从使用此声音的已保存歌曲中移除它。',
  ),
  removeError(
    'Couldn’t delete this item.',
    '이 항목을 삭제하지 못했어요.',
    '削除できませんでした。',
    '无法删除此项目。',
  ),
  soundPlayFailed(
    'Couldn’t play this sound.',
    '이 소리를 재생하지 못했어요.',
    'この音を再生できませんでした。',
    '无法播放此声音。',
  ),
  soundOpenFailed(
    'Couldn’t open this sound.',
    '이 소리를 열지 못했어요.',
    'この音を開けませんでした。',
    '无法打开此声音。',
  ),
  selection('Selection', '선택 구간', '選択範囲', '选定范围'),
  seconds('{0}s', '{0}초', '{0}秒', '{0} 秒'),
  pitch('Pitch', '음 높이', '音の高さ', '音高'),
  semitones('{0} semitones', '{0}반음', '{0} 半音', '{0} 个半音'),
  pitchHelp(
    'Raising pitch shortens the sound. Lowering it makes it longer.',
    '음을 높이면 짧아지고, 낮추면 길어져요.',
    '音を高くすると短くなり、低くすると長くなります。',
    '升高音高会缩短声音，降低音高会延长声音。',
  ),
  soundName('Sound name (optional)', '소리 이름 (선택)', '音の名前（任意）', '声音名称（选填）'),
  preview('Preview', '미리 듣기', '試聴', '试听'),
  saveClip('Save clip', '다듬은 소리 저장', 'クリップを保存', '保存片段'),
  nameTooLong(
    'Try a shorter sound name.',
    '소리 이름을 조금 더 짧게 입력해 주세요.',
    '音の名前を短くしてください。',
    '请缩短声音名称。',
  ),
  clipRange(
    'Choose a range longer than 0 seconds and within 5 minutes.',
    '0초보다 길고 5분 이하인 구간을 골라 주세요.',
    '0 秒より長く、5 分以内の範囲を選んでください。',
    '请选择大于 0 秒且不超过 5 分钟的范围。',
  ),
  clipLimit(
    'Choose a shorter range. The edited clip must fit within 5 minutes.',
    '편집한 소리가 5분 이내가 되도록 구간을 더 짧게 골라 주세요.',
    '編集後の音が 5 分以内になるよう、範囲を短くしてください。',
    '请缩短范围，编辑后的片段不得超过 5 分钟。',
  ),
  clipSaveError(
    'Couldn’t save this clip.',
    '다듬은 소리를 저장하지 못했어요.',
    'クリップを保存できませんでした。',
    '无法保存此片段。',
  ),
  previewError(
    'Couldn’t play the preview.',
    '미리 듣기를 재생하지 못했어요.',
    '試聴できませんでした。',
    '无法播放试听。',
  ),
  songName('Song name', '곡 이름', '曲名', '歌曲名称'),
  songNameRequired(
    'Enter a song name.',
    '곡 이름을 입력해 주세요.',
    '曲名を入力してください。',
    '请输入歌曲名称。',
  ),
  save('Save', '저장', '保存', '保存'),
  songSaveFailed(
    'Couldn’t save this song.',
    '곡을 저장하지 못했어요.',
    '曲を保存できませんでした。',
    '无法保存此歌曲。',
  ),
  songPlayFailed(
    'Couldn’t play this song. Check its sounds and the 5-minute limit.',
    '곡을 재생하지 못했어요. 소리 파일이 남아 있고 곡이 5분 이내인지 확인해 주세요.',
    '曲を再生できませんでした。音が残っているか、5 分以内の曲か確認してください。',
    '无法播放歌曲。请检查声音文件是否存在，以及歌曲是否在 5 分钟以内。',
  ),
  songLoadFailed(
    'Couldn’t load your songs.',
    '곡 목록을 불러오지 못했어요.',
    '曲を読み込めませんでした。',
    '无法加载歌曲。',
  ),
  songPartialLoad(
    'Some saved songs couldn’t be opened.',
    '저장한 곡 중 일부를 열지 못했어요.',
    '保存した曲の一部を開けませんでした。',
    '部分已保存的歌曲无法打开。',
  ),
  emptySongs(
    'Saved songs appear here.',
    '저장한 곡이 여기에 표시됩니다.',
    '保存した曲がここに表示されます。',
    '已保存的歌曲将在此显示。',
  ),
  deleteSong('Delete song', '곡 삭제', '曲を削除', '删除歌曲'),
  deleteSongConfirm(
    'Delete this song?',
    '이 곡을 삭제할까요?',
    'この曲を削除しますか？',
    '删除此歌曲？',
  ),
  editSong('Edit song', '곡 편집', '曲を編集', '编辑歌曲'),
  placementCount('Sounds: {0}', '소리 {0}개', '音 {0} 個', '声音：{0}'),
  overview('Song overview', '곡 전체', '曲全体', '歌曲预览'),
  track('Track {0}', '트랙 {0}', 'トラック {0}', '音轨 {0}'),
  trackLabel('Track', '트랙', 'トラック', '音轨'),
  clip('Clip', '소리', 'クリップ', '片段'),
  missingSound('Sound unavailable', '찾을 수 없는 소리', '音が見つかりません', '声音不可用'),
  emptyTrack(
    'No sounds on this track yet.',
    '이 트랙에 배치한 소리가 없어요.',
    'このトラックにはまだ音がありません。',
    '此音轨还没有声音。',
  ),
  addSound('Add sound', '소리 추가', '音を追加', '添加声音'),
  editPlacement('Edit placement', '배치 수정', '配置を編集', '编辑位置'),
  removePlacement('Remove placement', '배치 삭제', '配置を外す', '移除此片段'),
  startSeconds('Start time (seconds)', '시작 시간 (초)', '開始時刻（秒）', '开始时间（秒）'),
  startsAt('Starts at {0}s', '{0}초에 시작', '{0} 秒から', '从 {0} 秒开始'),
  startRange(
    'Enter a time between 0 and 300 seconds.',
    '0초 이상 300초 미만으로 입력해 주세요.',
    '0 秒以上 300 秒未満で入力してください。',
    '请输入大于等于 0 且小于 300 秒的时间。',
  ),
  songTooLong(
    'Move the sound earlier so the song stays within 5 minutes.',
    '곡이 5분을 넘지 않도록 소리를 앞쪽에 놓아 주세요.',
    '曲が 5 分以内になるよう音を手前に移してください。',
    '请将声音向前调整，使歌曲不超过 5 分钟。',
  ),
  apply('Apply', '적용', '適用', '应用'),
  chooseSounds('Choose your sounds', '사용할 소리 선택', '音を選ぶ', '选择声音'),
  aiHelp(
    'Choose up to 12 clips. Gemini uses their names, lengths, and your direction to suggest where to place them.',
    '소리를 최대 12개 고르세요. Gemini가 소리의 이름과 길이, 요청을 보고 배치를 제안합니다.',
    '最大 12 個の音を選んでください。Gemini が名前、長さ、希望をもとに配置を提案します。',
    '最多选择 12 个片段。Gemini 根据名称、时长和你的要求推荐编排。',
  ),
  mood(
    'Mood or direction (optional)',
    '원하는 분위기 (선택)',
    '雰囲気や希望（任意）',
    '氛围或要求（选填）',
  ),
  generate('Make arrangement', '배치안 만들기', '配置案を作る', '生成编排'),
  arranging('Making your arrangement…', '배치안을 만드는 중…', '配置案を作成中…', '正在生成编排…'),
  aiNoKey(
    'Add your Gemini API key in Settings first.',
    '먼저 설정에서 Gemini API 키를 등록해 주세요.',
    '先に設定で Gemini API キーを登録してください。',
    '请先在设置中添加 Gemini API 密钥。',
  ),
  aiInvalidResult(
    'Gemini couldn’t make a usable arrangement. Try again.',
    'Gemini가 사용할 수 있는 배치를 만들지 못했어요. 다시 시도해 주세요.',
    'Gemini が使える配置を作れませんでした。もう一度試してください。',
    'Gemini 未能生成可用的编排。请重试。',
  ),
  aiTimeout(
    'Gemini is taking too long to respond. Try again.',
    'Gemini 응답이 늦어요. 다시 시도해 주세요.',
    'Gemini の応答に時間がかかっています。もう一度試してください。',
    'Gemini 响应超时。请重试。',
  ),
  aiConnection(
    'Couldn’t connect to Gemini. Check your connection.',
    'Gemini에 연결하지 못했어요. 인터넷을 확인해 주세요.',
    'Gemini に接続できませんでした。通信を確認してください。',
    '无法连接 Gemini。请检查网络连接。',
  ),
  aiAccess(
    'Gemini rejected the request. Check the key and its permissions.',
    'Gemini가 요청을 거부했어요. 키와 사용 권한을 확인해 주세요.',
    'Gemini がリクエストを拒否しました。キーと権限を確認してください。',
    'Gemini 拒绝了请求。请检查密钥和权限。',
  ),
  aiQuota(
    'Gemini usage limit reached. Try again later.',
    'Gemini 사용 한도에 도달했어요. 잠시 뒤 다시 시도해 주세요.',
    'Gemini の利用上限に達しました。時間をおいて再試行してください。',
    '已达到 Gemini 使用上限。请稍后再试。',
  ),
  aiUnavailable(
    'Gemini couldn’t respond. Try again later.',
    'Gemini에서 응답하지 못했어요. 나중에 다시 시도해 주세요.',
    'Gemini が応答できませんでした。時間をおいて再試行してください。',
    'Gemini 无法响应。请稍后再试。',
  ),
  aiSelection(
    'Choose between 1 and 12 sounds.',
    '소리를 1개 이상 12개 이하로 골라 주세요.',
    '音を 1 個以上、12 個以内で選んでください。',
    '请选择 1 至 12 个声音。',
  );

  const L(this.en, this.ko, this.ja, this.zh);

  final String en;
  final String ko;
  final String ja;
  final String zh;

  String call(BuildContext context, [Object? value]) {
    final message = switch (AppLanguage.fromCode(
      Localizations.localeOf(context).languageCode,
    )) {
      AppLanguage.en => en,
      AppLanguage.ko => ko,
      AppLanguage.ja => ja,
      AppLanguage.zh => zh,
    };
    return value == null
        ? message
        : message.replaceAll('{0}', value.toString());
  }
}
