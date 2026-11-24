# BeatTake

[한국어 README](README.ko.md)

Turn the sounds around you into music, wherever you are. Record a desk tap, a zipper, or a footstep, then trim and layer those sounds into a short track on your phone.

Built for Vibe Forge by **Emong**.

## Open the web demo

[Try BeatTake in your browser](https://maoemong.github.io/BeatTake/). No sign-in is needed. Allow microphone access when you start recording. Your recordings and songs stay in the browser you use.

## Install the Android app

[Download BeatTake for Android](https://github.com/MaoEmong/BeatTake/releases/download/v1.0.0/BeatTake-1.0.0-android.apk). Open the APK on a device running **Android 7.0 or newer** and follow the installation prompt. Allow microphone access the first time you record.

## Try the main flow

1. On **Home**, choose **Record a sound**, capture a short sound, and tap **Stop and save**.
2. Trim the selection, adjust its pitch, and tap **Preview**. Use **Save clip** to keep your edit. Repeat to capture a second sound.
3. Choose **Make a song** on **Home**. Enter a title and use **Add sound** to place each clip on a track. Try placing them at different start times or overlapping them.
4. Tap **Play** to hear the result, then **Save**. Open **Songs** to replay or edit the saved arrangement.

Recording, editing, and playing saved songs need no account or API key. The Android app works offline for these features.

## Try AI arrangement

Enter your own OpenAI API key under **Settings**. In **AI Studio**, select one or more edited clips, optionally describe the mood, and tap **Make arrangement**. The suggested placements open in the track editor for playback, changes, and saving.

This feature needs an internet connection and an OpenAI API key with access to GPT-6 Luna. The web demo keeps that key in memory until you reload or close the page. On Android it is saved in the device’s secure storage. Requests go directly to OpenAI with the selected clip names and durations, the arrangement direction, and temporary labels for the clips. The audio stays in your library.

## How it works

BeatTake is built in Flutter. The app records and edits audio locally. Each saved song keeps a list of clips, tracks, and start times, so an arrangement remains editable. Playback mixes those clips on the device. AI suggestions are checked against the selected clips and the song length limit before opening the editor.

The starting materials were a Flutter app scaffold and product planning notes. Emong chose the app direction and the Track Lens layout. OpenAI Codex helped implement and test the app. An independent Codex review reproduced a duplicate save from rapid taps, which was fixed and covered by a regression test. After testing several AI integrations, Emong kept OpenAI for the submission.

## Build and verify

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build web --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The website is written to `build/web`. [Development and test notes](docs/development.md)

BeatTake uses Flutter and its Material icons, along with the audio and storage packages listed in [pubspec.yaml](pubspec.yaml). OpenAI powers the optional arrangement feature.
