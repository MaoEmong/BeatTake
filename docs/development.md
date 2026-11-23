# 실행 및 확인

## 작업 환경

프로젝트 이름은 `everyday_beats`다. Flutter 3.44.7과 Dart 3.12.2로 작업했고, Android와 iOS 프로젝트가 생성돼 있다. Android의 최소 지원 버전은 API 24다.

프로젝트 폴더에서 아래 명령을 실행한다. `flutter run`에는 연결된 휴대폰이나 가상 기기가 필요하다.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug
```

이 Windows PC에서는 `C:\flutter`의 설치 파일 일부가 빠져 있었다. 마지막으로 통과한 빌드는 `E:\portfolio\ieum\.build-tools\flutter\bin\flutter.bat`을 사용했다. Android SDK를 같은 위치에 둔 상태라면 다음처럼 실행할 수 있다.

```powershell
Set-Location 'E:\portfolio\vibeforge'
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'VibeForgeDev\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$vibeFlutter = 'E:\portfolio\ieum\.build-tools\flutter\bin\flutter.bat'
& $vibeFlutter doctor
& $vibeFlutter build apk --debug
```

- 마지막으로 빌드한 Android 설치 파일은 `build/app/outputs/flutter-apk/app-debug.apk`에 있다.
- Android 빌드에는 SDK 35와 36, NDK 28.2.13676358, CMake 3.22.1을 사용했다.
- 코드와 패키지가 각각 E 드라이브와 C 드라이브에 있어 발생했던 Android 빌드 오류를 피하도록 `android/gradle.properties`에 `kotlin.incremental=false`를 설정했다.
- iOS는 마이크 사용 권한 문구가 들어가 있다. 빌드와 기기 확인에는 macOS의 Xcode 환경이 필요하다.

## 코드와 파일

| 위치 | 하는 일 |
| --- | --- |
| [lib/main.dart](../lib/main.dart) | 녹음 화면, 마이크 권한 요청, 녹음 시작·정지, 녹음 목록과 재생을 담당한다. |
| [lib/recording_store.dart](../lib/recording_store.dart) | 녹음 파일을 저장하고, 앱이 다시 열릴 때 목록을 읽는다. |
| [lib/wav_audio.dart](../lib/wav_audio.dart) | 녹음 파일에서 선택 구간을 읽고 음 높이를 바꾼다. |
| [lib/song.dart](../lib/song.dart), [lib/song_store.dart](../lib/song_store.dart) | 각 소리의 배치에 맞춰 합친 재생 파일을 만들고, 곡의 배치를 저장한다. |
| [lib/ai_arranger.dart](../lib/ai_arranger.dart) | Gemini에 배치안을 요청하고 앱에서 쓸 수 있는 결과인지 검사한다. |
| [test/recording_store_test.dart](../test/recording_store_test.dart) | 새로 저장소를 열었을 때 파일을 다시 찾는지, 빈 녹음이 목록에 올라오지 않는지 확인한다. |
| [pubspec.yaml](../pubspec.yaml) | 녹음은 `record`, 재생은 `audioplayers`, 앱 저장 위치 확인은 `path_provider`를 사용한다. |

녹음 파일은 앱의 문서 저장공간 안에 있는 `recordings/` 폴더에 저장한다. 녹음 중에는 `draft_<시작시각>.wav`에 소리가 쌓인다. 정지가 끝나고 파일 저장이 완료되면 `recording_<시작시각>.wav`로 이름을 바꾼다. 앱은 최종 이름을 가진 파일만 읽어 최신순으로 표시한다. 현재 형식은 모노 WAV, 44.1 kHz다.

앱이 뒤로 전환되면 진행 중인 녹음을 마치고 저장하도록 구현했다. 저장이 완료된 파일은 재시작 후에도 남는다. 녹음 중에 운영체제가 앱을 즉시 종료하면 임시 파일이 남을 수 있다. 녹음 권한을 확인할 때는 Android의 `android/app/src/main/AndroidManifest.xml`과 iOS의 `ios/Runner/Info.plist`를 확인한다.

다듬은 소리는 `recordings/clips/`에 별도 WAV 파일로 저장한다. 음을 높이면 소리가 짧아지고, 낮추면 길어진다. 편집해서 저장하거나 곡으로 재생할 수 있는 길이는 최대 5분이다. 곡의 이름과 각 소리의 트랙 및 시작 시간은 `recordings/songs/`에 저장한다. 저장된 곡에 들어 있는 소리를 삭제하려면 해당 곡에서 배치를 먼저 지운다.

AI 편곡에는 개인 Gemini 키가 필요하다. 키는 기기의 보안 저장소에 보관하고, 편곡을 요청할 때 선택한 소리의 이름과 길이, 사용자가 입력한 요청만 Gemini에 보낸다. 배치안을 받아도 곡 파일에는 **곡 저장**을 눌렀을 때 반영된다.

## 확인 결과

- `flutter analyze`를 통과했고 `flutter test`의 두 테스트가 통과했다.
- Android 15 가상 휴대폰에 설치한 뒤 마이크 권한 허용, 녹음, 정지, 파일 저장을 확인했다.
- 앱을 강제로 종료했다 다시 열어 저장한 파일이 목록에 표시되고 재생되는 것을 확인했다. 저장된 WAV의 길이와 형식도 확인했다.
- 실제 휴대폰의 마이크와 iOS 빌드 및 재생은 확인 전이다.
