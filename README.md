# RadioScribe

Underground mine radio traffic monitor with offline speech-to-text and keyword alerting.

**© Shawn Baird. All rights reserved. Non-commercial use only.**

---

## Overview

RadioScribe monitors radio traffic through your phone's microphone, transcribes speech offline using Vosk, and alerts you when critical keywords are detected. Built for underground mining environments.

## Alert Tiers

| Level | Trigger | Color | Behavior |
|-------|---------|-------|----------|
| Normal | No match | White | Scrolls off naturally |
| Warning | Keyword match | CAT Yellow | Pinned, swipe to dismiss |
| Safety | Safety keyword | Snap-on Red | Pinned top, alarm after 20s |

## Setup Before Building

### 1. Vosk Model
Download the small English model from https://alphacephei.com/vosk/models

- Recommended: `vosk-model-small-en-us-0.15`
- Extract into `assets/models/vosk-model-small-en-us-0.15/`

### 2. Alarm Sound
Place an `alarm.mp3` file in `assets/sounds/`

### 3. Build
```bash
flutter pub get
flutter build apk --release
```

## Architecture

```
lib/
  main.dart               # App entry point
  theme/
    app_theme.dart        # Colors (CAT yellow, Snap-on red, dark bg)
  models/
    segment.dart          # TranscriptSegment data model
    keyword_config.dart   # Keyword lists + settings model
  services/
    audio_service.dart    # Mic input + Vosk STT (Vosk hooks here)
    keyword_service.dart  # Keyword/phrase matching engine
    settings_service.dart # Persistent settings via SharedPreferences
    transcript_log_service.dart  # Optional text log per session
  screens/
    splash_screen.dart    # Disclaimer + license
    main_menu_screen.dart # Main menu
    listen_screen.dart    # Live monitoring view
    settings_screen.dart  # Keyword editor + preferences
  widgets/
    segment_card.dart     # Swipeable segment display card
```

## Vosk Integration (TODO)

The `AudioService` in `lib/services/audio_service.dart` has a `_simulateRecognition()` placeholder. Replace with real Vosk calls:

1. Load model: `VoskFlutterPlugin.instance().initModel('assets/models/vosk-model-small-en-us-0.15')`
2. Start recognizer with silence threshold from `KeywordConfig.silenceThresholdMs`
3. On partial result: update `_partialText`
4. On final result: push to `_segmentController`

## License

Non-commercial use only. All rights reserved. © Shawn Baird.
