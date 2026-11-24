# BeatTake 배포와 Vibe Forge 제출

공개 웹 데모와 Android 1.0.0 설치 파일을 게시했습니다. 심사위원은 웹에서 바로 체험하거나 저장소의 Releases에서 안드로이드 앱을 설치할 수 있습니다. [웹 데모](https://maoemong.github.io/BeatTake/) · [GitHub 저장소](https://github.com/MaoEmong/BeatTake) · [Android APK](https://github.com/MaoEmong/BeatTake/releases/download/v1.0.0/BeatTake-1.0.0-android.apk)

## 웹 데모 배포하기

1. 앱 코드나 빌드 설정 변경을 GitHub의 `main`에 올립니다. GitHub는 코드 검사와 자동 테스트를 실행한 뒤 웹용 앱을 빌드하고 GitHub Pages에 게시합니다.
2. 같은 코드로 배포를 다시 실행할 때는 GitHub에서 **Actions → Publish BeatTake web demo → Run workflow**를 선택합니다. 브랜치는 `main`을 선택합니다. [배포 화면](https://github.com/MaoEmong/BeatTake/actions/workflows/pages.yml) · [GitHub 수동 실행 안내](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
3. 배포가 끝나면 로그인하지 않은 브라우저에서 데모를 열고, 홈 하단의 **Built for Vibe Forge by Emong**과 녹음·저장·재생을 확인합니다. [공개 데모](https://maoemong.github.io/BeatTake/)

## 안드로이드 APK 배포하기

1. 새 버전을 공개할 때는 `pubspec.yaml`에서 버전과 `+` 뒤의 빌드 번호를 올립니다. Flutter와 Android SDK가 준비된 환경에서 프로젝트 폴더를 열고 아래 명령을 실행합니다. [버전 설정](../pubspec.yaml) · [이 프로젝트에서 사용한 빌드 환경](development.md#작업-환경)

   ```sh
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --release
   ```

2. `build/app/outputs/flutter-apk/app-release.apk`를 기기나 가상 기기에 설치해 실행을 확인합니다. 기존 설치에 업데이트하려면 이전 APK와 같은 서명 키로 빌드합니다.
3. GitHub의 **Releases**에서 새 버전의 태그와 변경 내용을 적고 APK를 첨부해 게시합니다. 공개 후 README의 다운로드 링크도 새 버전으로 바꾸고, 로그인하지 않은 브라우저에서 내려받아 봅니다. [현재 1.0.0 릴리스](https://github.com/MaoEmong/BeatTake/releases/tag/v1.0.0) · [GitHub Releases 안내](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)

## Vibe Forge 참가자 화면에 넣을 내용

| 항목 | 제출할 내용 |
| --- | --- |
| 프로젝트 이름 | BeatTake |
| 제작자 표시 이름 | Emong |
| 공개 데모 링크 | [GitHub Pages 웹 데모](https://maoemong.github.io/BeatTake/) |
| 저장소 링크 (선택) | [BeatTake 저장소](https://github.com/MaoEmong/BeatTake) |
| 프로젝트 소개 및 AI 사용 내역 | 아래 영문 문구 |
| 시연 영상 | 보완본 `BeatTake-VibeForge-Demo.mp4`(1분 54.5초, 약 3.2MB)를 올리거나 심사위원이 로그인 없이 열 수 있는 영상 링크를 입력 |

현재 규정의 기본 영상 길이는 **2분 이내**이고 파일로 올릴 때는 **최대 250MB**입니다. 앱 화면과 음성 설명으로 녹음, 편집, 곡 배치와 재생을 보여 주고, 앱의 구성과 AI를 어디에 썼는지 짧게 설명합니다. 개인 API 키는 영상에 가립니다. [Vibe Forge 공식 규정 4·5·8항](https://vibe-forge.in/rules)

참가자 화면에 표시되는 마감 시각을 기준으로 준비합니다. 최종 제출 후에는 소개와 영상을 수정할 수 없으므로, 제출 버튼을 누르기 전에 웹 데모와 영상 링크가 로그인 없이 열리는지 확인합니다. [공식 규정](https://vibe-forge.in/rules) · [공식 일정](https://vibe-forge.in/timeline)

### 프로젝트 소개

> BeatTake helps people new to music-making turn sounds they notice on the spot into a track. Record a desk tap or a footstep, trim it, change its pitch, and layer it with other clips. Save the song and open it again to play or edit it. The browser demo opens without an account, and the Android app is available on GitHub Releases.

### 개발 도구와 AI 사용 내역

> I started with a Flutter scaffold and planning notes. I chose the Track Lens layout and asked OpenAI Codex to build the recording, editing, and song-making screens, then review the complete flow. That review reproduced duplicate songs when Save was tapped twice quickly. We blocked a second save while the first was in progress and added a test that confirms only one song is saved.
>
> I kept OpenAI for the submission after verifying that a live arrangement could be edited, saved, and replayed. In AI Studio, the prompt asks for track numbers and start times for the selected sounds. BeatTake checks those placements and opens them for editing.

### 다음 개발 계획

> I plan to add WAV export so people can share finished tracks or use them in another music app. I also plan to test microphone permission, recording interruptions, and playback across more phones and mobile browsers.

### 제출 전 확인

- 공개 데모에서 로그인 없이 홈 화면이 열리고 하단에 **Built for Vibe Forge by Emong**이 보이는지 확인합니다. 심사위원은 로그인이나 API 키 없이 녹음·편집·수동 곡 만들기를 체험할 수 있습니다. AI 편곡 결과는 시연 영상에서 볼 수 있습니다.
- 공개 저장소에서 영문 README, 한국어 README, Android APK를 열 수 있는지 확인합니다.
- 영상 파일을 올릴 경우 길이와 용량을 확인합니다. 영상 링크를 넣는 경우에는 로그인 없이 재생할 수 있는지 확인합니다.
