# BeatTake

[한국어 README](README.ko.md)

BeatTake helps people new to music-making turn sounds they notice on the spot into short tracks. Record a desk tap, a zipper, or a footstep, then trim and layer those sounds in the browser or on Android.

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

## Development choices and AI

Emong started with a Flutter scaffold and planning notes, defined the flow from recording to an editable song, and chose the Track Lens layout. Emong used OpenAI Codex to build that flow, then asked for a separate review of the real recording, editing, and saving steps.

The review reproduced a duplicate song when **Save** was tapped twice quickly. The fix accepts one save while a write is in progress. An automated test now checks that two quick taps create one song and take the user back to the library.

Emong kept OpenAI for AI Studio after confirming that a live arrangement could be edited, saved, and replayed. The prompt asks OpenAI to use the selected clips and return their track numbers and start times. BeatTake checks the suggested placements and opens them in the same editor used for manual arrangements. [Development and test notes](docs/development.md)

## Next steps

Add WAV export so users can share a finished track or bring it into another music app. Test recording, interruptions, and playback on a wider range of phones and mobile browsers.

## Build and verify

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter build web --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. The website is written to `build/web`. [Development and test notes](docs/development.md) · [Vibe Forge submission guide](docs/deployment.md)

BeatTake uses Flutter and its Material icons, along with the audio and storage packages listed in [pubspec.yaml](pubspec.yaml). OpenAI powers the optional arrangement feature.
