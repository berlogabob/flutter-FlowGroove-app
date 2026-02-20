# Reaper DAW Metronome Implementation Analysis

## Executive Summary

This document analyzes Reaper DAW's metronome implementation and provides recommendations for implementing a similar metronome system in Flutter/Web using Web Audio API principles. The analysis covers sound generation, UI/UX patterns, timing precision, and technical implementation approaches.

---

## 1. Reaper Metronome Behavior Analysis

### 1.1 Core Settings

Reaper's metronome uses the following default configuration:

| Setting | Value | Description |
|---------|-------|-------------|
| **Primary beat volume** | 0.00 dB | Downbeat (beat 1) volume |
| **Secondary beat volume** | -6.04 dB | Other beats volume (~50% quieter) |
| **Primary beat frequency** | 2000 Hz | Higher pitch for accent |
| **Secondary beat frequency** | 1200 Hz | Lower pitch for regular beats |
| **Beat click length** | 40 ms | Duration of each click |
| **Waveform shape** | Sine with soft start | Smooth attack to avoid clicks |

### 1.2 Sound Generation Methods

Reaper supports two approaches:

1. **Built-in Synthesized Click**
   - Sine wave with soft attack envelope
   - Different frequencies for primary/secondary beats
   - Configurable volume offset between beat types

2. **Custom WAV Samples**
   - Users can replace default sounds with custom WAV files
   - Separate sounds for primary and secondary beats
   - 66+ pre-made sounds available (including imports from Pro Tools)

### 1.3 Accent Handling

Reaper implements accents through:
- **Frequency differentiation**: Primary beat at 2000Hz vs secondary at 1200Hz
- **Volume differentiation**: Primary beat 6dB louder than secondary
- **Pattern customization**: Users can define custom beat patterns via right-click menu
  - Supports triplets, straight rhythms, custom accent patterns
- **Speed multiplier**: Up to 4x speed for double-time/half-time practice

### 1.4 Time Signature Support

Reaper supports:
- **Standard signatures**: 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 8/8, etc.
- **Compound signatures**: 3+4, 5+3, etc.
- **Custom patterns**: User-defined beat patterns
- **Time signature markers**: Different signatures can change within a project

**UI Pattern:**
- Right-click metronome icon to access settings dialog
- Time signature set via project settings or markers
- Pattern entered as string (e.g., "1221222" where 1=primary, 2=secondary)

---

## 2. Web Audio API Sound Synthesis

### 2.1 Oscillator Types

The Web Audio API provides four basic waveform types:

```javascript
const audioContext = new AudioContext();
const oscillator = audioContext.createOscillator();

// Available waveform types
oscillator.type = 'sine';      // Smooth, pure tone (Reaper default)
oscillator.type = 'square';    // Harsh, rich in harmonics (good for accents)
oscillator.type = 'triangle';  // Mellow, between sine and square
oscillator.type = 'sawtooth';  // Bright, buzzy sound
```

### 2.2 Complete Sound Synthesis Implementation

```javascript
class MetronomeSound {
  constructor(audioContext) {
    this.audioContext = audioContext;
  }

  /**
   * Play a metronome click with configurable parameters
   * @param {number} time - AudioContext time to play the sound
   * @param {boolean} isAccented - Whether this is an accented beat
   * @param {object} options - Sound configuration
   */
  playClick(time, isAccented = false, options = {}) {
    const {
      accentedFreq = 2000,      // Hz - Reaper primary beat frequency
      unaccentedFreq = 1200,    // Hz - Reaper secondary beat frequency
      accentedVolume = 1.0,     // 0-1 scale (0 dB)
      unaccentedVolume = 0.5,   // 0-1 scale (-6 dB)
      duration = 0.04,          // 40ms - Reaper default
      waveType = 'sine'         // 'sine', 'square', 'triangle', 'sawtooth'
    } = options;

    const oscillator = this.audioContext.createOscillator();
    const gainNode = this.audioContext.createGain();

    // Configure oscillator
    oscillator.type = isAccented ? 'square' : waveType;  // Square for accent
    oscillator.frequency.value = isAccented ? accentedFreq : unaccentedFreq;

    // Create amplitude envelope (avoid clicking artifacts)
    gainNode.gain.setValueAtTime(0, time);
    gainNode.gain.linearRampToValueAtTime(
      isAccented ? accentedVolume : unaccentedVolume,
      time + 0.001  // 1ms attack
    );
    gainNode.gain.exponentialRampToValueAtTime(
      0.001,
      time + duration
    );

    // Connect and schedule
    oscillator.connect(gainNode);
    gainNode.connect(this.audioContext.destination);

    oscillator.start(time);
    oscillator.stop(time + duration + 0.01);  // Small buffer
  }
}
```

### 2.3 Frequency and Duration Parameters

Based on Reaper's defaults and audio best practices:

| Parameter | Recommended Value | Range | Description |
|-----------|------------------|-------|-------------|
| **Accented frequency** | 2000 Hz | 1500-3000 Hz | Higher pitch for downbeat |
| **Unaccented frequency** | 1200 Hz | 800-1500 Hz | Lower pitch for other beats |
| **Click duration** | 40 ms | 20-60 ms | Short percussive sound |
| **Attack time** | 1 ms | 0.5-5 ms | Soft start to avoid clicks |
| **Accented volume** | 1.0 (0 dB) | 0.5-1.0 | Louder for emphasis |
| **Unaccented volume** | 0.5 (-6 dB) | 0.3-0.7 | Quieter for contrast |

---

## 3. Precise Timing Implementation

### 3.1 The Lookahead Scheduling Pattern

The industry-standard approach for precise metronome timing (popularized by Chris Wilson, Google Chrome audio team):

```javascript
class PreciseMetronome {
  constructor(bpm = 120, beatsPerMeasure = 4) {
    this.audioContext = null;
    this.bpm = bpm;
    this.beatsPerMeasure = beatsPerMeasure;
    this.isPlaying = false;

    // Timing state
    this.currentBeat = 0;
    this.nextNoteTime = 0.0;

    // Lookahead parameters (critical for precision)
    this.scheduleAheadTime = 0.1;  // Schedule 100ms ahead
    this.lookahead = 25.0;          // Check every 25ms

    this.timerId = null;
    this.soundGenerator = null;
  }

  /**
   * Initialize AudioContext (must be called after user gesture)
   */
  init() {
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)();
    }
    this.soundGenerator = new MetronomeSound(this.audioContext);
  }

  /**
   * Calculate time for next beat based on current tempo
   */
  nextNote() {
    const secondsPerBeat = 60.0 / this.bpm;
    this.nextNoteTime += secondsPerBeat;
    this.currentBeat = (this.currentBeat + 1) % this.beatsPerMeasure;
  }

  /**
   * Schedule a note at the specified time
   */
  scheduleNote(beatNumber, time) {
    const isAccented = beatNumber === 0;  // First beat of measure
    this.soundGenerator.playClick(time, isAccented);

    // Optional: Trigger UI update (with slight delay for visual sync)
    setTimeout(() => {
      this.onBeatCallback?.(beatNumber);
    }, (time - this.audioContext.currentTime) * 1000);
  }

  /**
   * Scheduler function - called repeatedly by timer
   */
  scheduler() {
    // Schedule any notes that fall within the lookahead window
    while (this.nextNoteTime < this.audioContext.currentTime + this.scheduleAheadTime) {
      this.scheduleNote(this.currentBeat, this.nextNoteTime);
      this.nextNote();
    }

    if (this.isPlaying) {
      this.timerId = setTimeout(() => this.scheduler(), this.lookahead);
    }
  }

  /**
   * Start the metronome
   */
  start() {
    if (this.isPlaying) return;

    this.init();

    // Resume audio context if suspended (browser autoplay policy)
    if (this.audioContext.state === 'suspended') {
      this.audioContext.resume();
    }

    this.isPlaying = true;
    this.currentBeat = 0;
    this.nextNoteTime = this.audioContext.currentTime + 0.05;

    this.scheduler();
  }

  /**
   * Stop the metronome
   */
  stop() {
    this.isPlaying = false;
    if (this.timerId) {
      clearTimeout(this.timerId);
      this.timerId = null;
    }
  }

  /**
   * Set beats per minute
   */
  setBPM(bpm) {
    this.bpm = bpm;
  }

  /**
   * Set time signature (beats per measure)
   */
  setTimeSignature(beatsPerMeasure) {
    this.beatsPerMeasure = beatsPerMeasure;
  }

  /**
   * Callback for beat events (UI updates)
   */
  set onBeatCallback(callback) {
    this._onBeatCallback = callback;
  }
}
```

### 3.2 Why This Pattern Works

| Technique | Problem Solved | Solution |
|-----------|---------------|----------|
| **AudioContext.currentTime** | JavaScript timers have ~40ms variance | Hardware-level sub-millisecond precision |
| **Lookahead buffer (100ms)** | Scheduler delays cause missed beats | Schedule notes well before they need to play |
| **Frequent checks (25ms)** | Long intervals miss scheduling windows | Check often enough to catch all notes |
| **Overlap strategy** | Timer variance accumulates | 25ms check + 100ms buffer = no gaps |

### 3.3 AudioWorklet for Advanced Timing

For even more precise timing (advanced use case):

```javascript
// Main thread
const audioContext = new AudioContext();
await audioContext.audioWorklet.addModule('metronome-processor.js');
const metronomeNode = new AudioWorkletNode(audioContext, 'metronome-processor');
metronomeNode.connect(audioContext.destination);

// Send BPM updates
metronomeNode.port.postMessage({ type: 'bpm', value: 120 });

// metronome-processor.js (runs in audio thread)
class MetronomeProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.bpm = 120;
    this.nextBeatTime = 0;
    this.sampleRate = sampleRate;
    this.samplesPerBeat = (sampleRate * 60) / this.bpm;
    this.currentSample = 0;

    this.port.onmessage = (event) => {
      if (event.data.type === 'bpm') {
        this.bpm = event.data.value;
        this.samplesPerBeat = (this.sampleRate * 60) / this.bpm;
      }
    };
  }

  process(inputs, outputs, parameters) {
    const output = outputs[0];
    const channel = output[0];

    if (this.currentSample >= this.nextBeatTime) {
      // Generate click sound
      for (let i = 0; i < channel.length && this.currentSample < this.nextBeatTime + 1764; i++) {
        channel[i] = Math.sin(2 * Math.PI * 2000 * (this.currentSample / this.sampleRate)) *
                     Math.exp(-(this.currentSample - this.nextBeatTime) / 441);
        this.currentSample++;
      }
      this.nextBeatTime += this.samplesPerBeat;
      this.port.postMessage({ type: 'beat' });
    }

    return true;
  }
}

registerProcessor('metronome-processor', MetronomeProcessor);
```

---

## 4. UI/UX Design Recommendations

### 4.1 Time Signature Display Pattern

Following Reaper's approach and standard music notation:

```
┌─────────────────────────────────────┐
│         Time Signature              │
│                                     │
│    ┌─────────┐     ┌─────────┐     │
│    │    4    │     │    4    │     │
│    └─────────┘     └─────────┘     │
│      Numerator     Denominator      │
│   (Beats/Measure)   (Beat Unit)     │
│                                     │
│    Display: "4 / 4"                 │
└─────────────────────────────────────┘
```

### 4.2 Dropdown Options

**Numerator Dropdown (Beats per Measure):**
```dart
final numerators = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
```

**Denominator Dropdown (Beat Unit):**
```dart
final denominators = [
  {'value': 2, 'label': 'Half note (2)'},
  {'value': 4, 'label': 'Quarter note (4)'},
  {'value': 8, 'label': 'Eighth note (8)'},
  {'value': 16, 'label': 'Sixteenth note (16)'},
];
```

### 4.3 Complete UI Layout

```
┌─────────────────────────────────────────────────────────┐
│                    METRONOME                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │              BPM: 120                           │   │
│  │  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │   │
│  │  30                                    600     │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Time Signature                        │   │
│  │                                                 │   │
│  │    ┌──────────────┐       ┌──────────────┐     │   │
│  │    │      4       │   /   │      4       │     │   │
│  │    └──────────────┘       └──────────────┘     │   │
│  │         Beats                  Beat Unit        │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Beat Visualization                    │   │
│  │                                                 │   │
│  │    ●    ○    ○    ○                            │   │
│  │    1    2    3    4                            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Accent Settings                       │   │
│  │                                                 │   │
│  │    [✓] Accent on beat 1                         │   │
│  │    Primary Volume:   ━━━━━━━━━━━━ 0 dB         │   │
│  │    Secondary Volume: ━━━━━━━━ -6 dB            │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │           Sound Settings                        │   │
│  │                                                 │   │
│  │    Primary Frequency:   ━━━━━━━━━━━━ 2000 Hz   │   │
│  │    Secondary Frequency: ━━━━━━━━━━━━ 1200 Hz   │   │
│  │    Click Duration:      ━━━━━━━━ 40 ms         │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│                    [ ▶ PLAY ]                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4.4 Flutter Widget Implementation

```dart
class MetronomeControls extends StatefulWidget {
  @override
  _MetronomeControlsState createState() => _MetronomeControlsState();
}

class _MetronomeControlsState extends State<MetronomeControls> {
  int bpm = 120;
  int numerator = 4;
  int denominator = 4;
  double primaryVolume = 1.0;
  double secondaryVolume = 0.5;
  double primaryFrequency = 2000;
  double secondaryFrequency = 1200;
  bool accentEnabled = true;

  final List<int> numerators = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
  final List<Map<String, dynamic>> denominators = [
    {'value': 2, 'label': '2 (Half)'},
    {'value': 4, 'label': '4 (Quarter)'},
    {'value': 8, 'label': '8 (Eighth)'},
    {'value': 16, 'label': '16 (Sixteenth)'},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BPM Slider
        _buildBpmSlider(),

        // Time Signature Dropdowns
        _buildTimeSignatureDropdowns(),

        // Beat Visualization
        _buildBeatVisualization(),

        // Accent Toggle
        _buildAccentControls(),

        // Sound Settings
        _buildSoundSettings(),

        // Play Button
        _buildPlayButton(),
      ],
    );
  }

  Widget _buildBpmSlider() {
    return Column(
      children: [
        Text('BPM: $bpm', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Slider(
          value: bpm.toDouble(),
          min: 30,
          max: 600,
          divisions: 570,
          onChanged: (value) {
            setState(() => bpm = value.toInt());
          },
          onChangeEnd: (value) {
            // Update metronome
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text('30'), Text('600')],
        ),
      ],
    );
  }

  Widget _buildTimeSignatureDropdowns() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Numerator Dropdown
        DropdownButton<int>(
          value: numerator,
          items: numerators.map((n) => DropdownMenuItem(
            value: n,
            child: Text('$n', style: TextStyle(fontSize: 24)),
          )).toList(),
          onChanged: (value) => setState(() => numerator = value!),
        ),
        Text(' / ', style: TextStyle(fontSize: 24)),
        // Denominator Dropdown
        DropdownButton<int>(
          value: denominator,
          items: denominators.map((d) => DropdownMenuItem(
            value: d['value'],
            child: Text(d['label'].split(' ')[0], style: TextStyle(fontSize: 24)),
          )).toList(),
          onChanged: (value) => setState(() => denominator = value!),
        ),
      ],
    );
  }

  Widget _buildBeatVisualization() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(numerator, (index) {
        final isCurrentBeat = false; // Track current beat from metronome
        final isAccented = index == 0;
        return Container(
          width: 40,
          height: 40,
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isCurrentBeat
                ? (isAccented ? Colors.red : Colors.orange)
                : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: isCurrentBeat ? Colors.white : Colors.black,
                fontWeight: isAccented ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAccentControls() {
    return Column(
      children: [
        SwitchListTile(
          title: Text('Accent on beat 1'),
          value: accentEnabled,
          onChanged: (value) => setState(() => accentEnabled = value),
        ),
        if (accentEnabled) ...[
          _buildVolumeSlider('Primary', primaryVolume, (v) => primaryVolume = v),
          _buildVolumeSlider('Secondary', secondaryVolume, (v) => secondaryVolume = v),
        ],
      ],
    );
  }

  Widget _buildVolumeSlider(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 1,
            onChanged: onChanged,
          ),
        ),
        Text('${(value * 100).toInt()}%'),
      ],
    );
  }

  Widget _buildSoundSettings() {
    return ExpansionTile(
      title: Text('Sound Settings'),
      children: [
        _buildFrequencySlider('Primary Frequency', primaryFrequency, 800, 3000, (v) => primaryFrequency = v),
        _buildFrequencySlider('Secondary Frequency', secondaryFrequency, 400, 2000, (v) => secondaryFrequency = v),
      ],
    );
  }

  Widget _buildFrequencySlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: 22,
            onChanged: onChanged,
          ),
        ),
        Text('${value.toInt()} Hz'),
      ],
    );
  }

  Widget _buildPlayButton() {
    return FloatingActionButton.large(
      onPressed: () {
        // Toggle metronome play/stop
      },
      child: Icon(Icons.play_arrow),
    );
  }
}
```

---

## 5. Flutter Implementation Approach

### 5.1 Recommended Packages

| Package | Purpose | Latency |
|---------|---------|---------|
| **metronome** (pub.dev) | Dedicated metronome plugin | Low (native) |
| **audioplayers** (LOW_LATENCY mode) | Audio playback | Medium |
| **just_audio** | Advanced audio control | Medium |
| **flutter_soloud** | Ultra-low latency audio | Very Low |

### 5.2 Using the `metronome` Package

```dart
import 'package:metronome/metronome.dart';

class MetronomeService {
  final _metronome = Metronome();

  Future<void> init() async {
    await _metronome.init(
      'assets/audio/click.wav',
      accentedPath: 'assets/audio/click_accented.wav',
      bpm: 120,
      volume: 50,
      enableTickCallback: true,
      timeSignature: 4,
      sampleRate: 44100,
    );

    // Listen for tick events (UI updates)
    _metronome.tickStream.listen((tick) {
      print('Beat: $tick');
      // Update UI to show current beat
    });
  }

  void play() => _metronome.play();
  void pause() => _metronome.pause();
  void setBPM(int bpm) => _metronome.setBPM(bpm);
  void setVolume(int volume) => _metronome.setVolume(volume);
  void setTimeSignature(int signature) => _metronome.setTimeSignature(signature);

  void setAudioFiles({String? mainPath, String? accentedPath}) {
    _metronome.setAudioFile(mainPath: mainPath, accentedPath: accentedPath);
  }

  void dispose() => _metronome.destroy();
}
```

### 5.3 Web Audio API Implementation (for Flutter Web)

```dart
@JS()
library metronome_web;

import 'package:web/web.dart' as web;
import 'dart:js_interop';

@JS('AudioContext')
extension type AudioContext._(web.AudioContext _jsAudioContext) implements Object {
  external AudioContext();
  external double get currentTime;
  external AudioDestinationNode get destination;
  external Future<void> resume();
  external String get state;
}

@JS('OscillatorNode')
extension type OscillatorNode._(web.OscillatorNode _jsOscillatorNode) implements Object {
  external set type(String value);
  external AudioParam get frequency;
  external void connect(AudioNode destination);
  external void start(double when);
  external void stop(double when);
}

@JS('GainNode')
extension type GainNode._(web.GainNode _jsGainNode) implements Object {
  external AudioParam get gain;
  external void connect(AudioNode destination);
}

class WebMetronome {
  late AudioContext _audioContext;
  bool _isPlaying = false;
  int _bpm = 120;
  int _beatsPerMeasure = 4;
  int _currentBeat = 0;
  double _nextNoteTime = 0;

  final double _scheduleAheadTime = 0.1;
  final double _lookahead = 25.0;

  void init() {
    _audioContext = AudioContext();
  }

  void _scheduleNote(int beatNumber, double time) {
    final oscillator = _audioContext.createOscillator() as OscillatorNode;
    final gainNode = _audioContext.createGain() as GainNode;

    final isAccented = beatNumber == 0;
    oscillator.type = isAccented ? 'square' : 'sine';
    oscillator.frequency.value = (isAccented ? 2000 : 1200).toJS;

    // Envelope
    gainNode.gain.setValueAtTime(0.toJS, time.toJS);
    gainNode.gain.linearRampToValueAtTime(
      (isAccented ? 1.0 : 0.5).toJS,
      (time + 0.001).toJS,
    );
    gainNode.gain.exponentialRampToValueAtTime(
      0.001.toJS,
      (time + 0.04).toJS,
    );

    oscillator.connect(gainNode);
    gainNode.connect(_audioContext.destination);

    oscillator.start(time.toJS);
    oscillator.stop((time + 0.05).toJS);
  }

  void _scheduler() {
    while (_nextNoteTime < _audioContext.currentTime + _scheduleAheadTime) {
      _scheduleNote(_currentBeat, _nextNoteTime);
      _nextNoteTime += 60.0 / _bpm;
      _currentBeat = (_currentBeat + 1) % _beatsPerMeasure;
    }

    if (_isPlaying) {
      web.window.setTimeout(_scheduler.toJS, _lookahead.toInt());
    }
  }

  void start() {
    if (_isPlaying) return;

    init();

    if (_audioContext.state == 'suspended') {
      _audioContext.resume();
    }

    _isPlaying = true;
    _currentBeat = 0;
    _nextNoteTime = _audioContext.currentTime + 0.05;
    _scheduler();
  }

  void stop() {
    _isPlaying = false;
  }

  void setBPM(int bpm) => _bpm = bpm;
  void setTimeSignature(int beats) => _beatsPerMeasure = beats;
}
```

---

## 6. Summary and Recommendations

### 6.1 Sound Synthesis

**For Flutter Mobile:**
- Use pre-rendered WAV files for primary/secondary beats
- Recommended frequencies: 2000Hz (accented), 1200Hz (unaccented)
- Duration: 40ms with soft attack envelope

**For Flutter Web:**
- Use Web Audio API OscillatorNode
- Sine wave for regular beats, square wave for accented
- Same frequency/volume parameters as Reaper

### 6.2 Timing Precision

**Critical Requirements:**
1. Use lookahead scheduling pattern (25ms check, 100ms buffer)
2. Schedule audio using AudioContext.currentTime (not JavaScript timers)
3. For Flutter mobile, use native metronome plugin or low-latency audio

### 6.3 UI Components

**Essential Controls:**
1. BPM slider (30-600 range)
2. Time signature dropdowns (numerator: 2-12, denominator: 2,4,8,16)
3. Beat visualization (circles showing current beat)
4. Accent toggle with volume controls
5. Sound settings (frequency, duration)

### 6.4 File Structure Recommendation

```
lib/
├── metronome/
│   ├── metronome_service.dart      # Core metronome logic
│   ├── metronome_sound.dart        # Sound generation (Web Audio API)
│   ├── metronome_timing.dart       # Lookahead scheduler
│   └── metronome_state.dart        # BPM, time signature state
├── ui/
│   ├── metronome_controls.dart     # Main control widget
│   ├── bpm_slider.dart             # BPM control
│   ├── time_signature_picker.dart  # Two dropdowns
│   ├── beat_visualization.dart     # Beat indicators
│   └── accent_controls.dart        # Accent toggle + sliders
└── audio/
    ├── click.wav                   # Regular beat sound
    └── click_accented.wav          # Accented beat sound
```

---

## References

1. Reaper DAW Metronome Settings - Admiral Bumblebee
2. Chris Wilson's Web Audio Metronome - GitHub
3. MDN Web Audio API Documentation
4. Flutter Metronome Package - pub.dev
5. W3C Web Audio Use Cases Specification
