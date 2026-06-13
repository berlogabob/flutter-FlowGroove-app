# Tuner platform requirements

The tuner processes mono PCM audio locally. Raw microphone audio is not
persisted or sent over the network.

## Android

`android.permission.RECORD_AUDIO` is declared in the application manifest.
Users can restore blocked access from the Android application settings.

## iOS and macOS

Both targets include `NSMicrophoneUsageDescription`. The macOS sandbox
entitlements include `com.apple.security.device.audio-input` for debug,
profile, and release builds.

## Web

Microphone capture requires HTTPS, except on `localhost`, `127.0.0.1`, and
`::1`. Pitch analysis remains on the client and the tuner works without a
server connection after application assets have loaded.

## Windows

No application manifest capability is required by the Flutter `record`
backend. Windows privacy settings can still disable microphone access for
desktop applications.

## Linux

The `record` Linux backend requires PulseAudio/PipeWire compatibility tools
and FFmpeg to be installed on the host:

```sh
sudo apt install pulseaudio-utils ffmpeg
```

`parecord` provides audio input and `pactl` provides device discovery.
