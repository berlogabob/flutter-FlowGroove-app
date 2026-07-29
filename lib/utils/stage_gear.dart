/// Static stage gear catalog and lookup utilities for Event Kit stage plots.
library;

/// A piece of stage gear available to place on a stage plot.
typedef GearEntry = ({
  String id,
  String name,
  String icon,
  String category,
  bool brandable,
  List<String> aliases,
});

/// Built-in stage gear entries and helpers for searching and suggestions.
class StageGear {
  StageGear._();

  /// All stage gear available to the Event Kit stage plot.
  static const List<GearEntry> catalog = [
    (
      id: 'drum_kit',
      name: 'Drum kit',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: true,
      aliases: ['drums', 'acoustic drums'],
    ),
    (
      id: 'kick_drum',
      name: 'Kick drum',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['bass drum'],
    ),
    (
      id: 'snare_drum',
      name: 'Snare drum',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['snare'],
    ),
    (
      id: 'hi_hat',
      name: 'Hi-hat',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['hihat', 'hi hat'],
    ),
    (
      id: 'floor_tom',
      name: 'Floor tom',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: [],
    ),
    (
      id: 'rack_tom',
      name: 'Rack tom',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['mounted tom'],
    ),
    (
      id: 'ride_cymbal',
      name: 'Ride cymbal',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['ride'],
    ),
    (
      id: 'crash_cymbal',
      name: 'Crash cymbal',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['crash'],
    ),
    (
      id: 'drum_throne',
      name: 'Drum throne',
      icon: '🪑',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['drum stool'],
    ),
    (
      id: 'drum_riser',
      name: 'Drum riser',
      icon: '🪑',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['drum platform'],
    ),
    (
      id: 'electronic_drum_kit',
      name: 'Electronic drum kit',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: true,
      aliases: ['e-drums', 'electric drums'],
    ),
    (
      id: 'cajon',
      name: 'Cajon',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['box drum'],
    ),
    (
      id: 'congas',
      name: 'Congas',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['conga drums'],
    ),
    (
      id: 'bongos',
      name: 'Bongos',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['bongo drums'],
    ),
    (
      id: 'djembe',
      name: 'Djembe',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['hand drum'],
    ),
    (
      id: 'timbales',
      name: 'Timbales',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: [],
    ),
    (
      id: 'tambourine',
      name: 'Tambourine',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['tambourin'],
    ),
    (
      id: 'shaker',
      name: 'Shaker',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['egg shaker', 'maraca'],
    ),
    (
      id: 'cowbell',
      name: 'Cowbell',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['cow bell'],
    ),
    (
      id: 'triangle',
      name: 'Triangle',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: [],
    ),
    (
      id: 'vibraphone',
      name: 'Vibraphone',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['vibes'],
    ),
    (
      id: 'xylophone',
      name: 'Xylophone',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['xylo'],
    ),
    (
      id: 'marimba',
      name: 'Marimba',
      icon: '🪘',
      category: 'Drums & percussion',
      brandable: false,
      aliases: [],
    ),
    (
      id: 'drum_shield',
      name: 'Drum shield',
      icon: '🥁',
      category: 'Drums & percussion',
      brandable: false,
      aliases: ['drum screen', 'acrylic shield'],
    ),
    (
      id: 'electric_guitar',
      name: 'Electric guitar',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['electric'],
    ),
    (
      id: 'acoustic_guitar',
      name: 'Acoustic guitar',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['acoustic'],
    ),
    (
      id: 'twelve_string_guitar',
      name: '12-string guitar',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['12 string', 'twelve string guitar'],
    ),
    (
      id: 'classical_guitar',
      name: 'Classical guitar',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['nylon string guitar'],
    ),
    (
      id: 'resonator_guitar',
      name: 'Resonator guitar',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['dobro', 'resonator'],
    ),
    (
      id: 'lap_steel',
      name: 'Lap steel',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['lap steel guitar'],
    ),
    (
      id: 'pedal_steel',
      name: 'Pedal steel',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['pedal steel guitar'],
    ),
    (
      id: 'banjo',
      name: 'Banjo',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: [],
    ),
    (
      id: 'mandolin',
      name: 'Mandolin',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['mandoline'],
    ),
    (
      id: 'ukulele',
      name: 'Ukulele',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['uke'],
    ),
    (
      id: 'bass_guitar',
      name: 'Bass guitar',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['electric bass', 'bass'],
    ),
    (
      id: 'five_string_bass',
      name: '5-string bass',
      icon: '🎸',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['5 string bass', 'five string bass'],
    ),
    (
      id: 'upright_bass',
      name: 'Upright bass',
      icon: '🎻',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['double bass', 'standup bass'],
    ),
    (
      id: 'guitar_stand',
      name: 'Guitar stand',
      icon: '🪑',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['instrument stand'],
    ),
    (
      id: 'bass_stand',
      name: 'Bass stand',
      icon: '🪑',
      category: 'Guitars & bass',
      brandable: false,
      aliases: ['bass guitar stand'],
    ),
    (
      id: 'keyboard',
      name: 'Keyboard',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['electric keyboard'],
    ),
    (
      id: 'stage_piano',
      name: 'Stage piano',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['digital piano'],
    ),
    (
      id: 'grand_piano',
      name: 'Grand piano',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['concert grand'],
    ),
    (
      id: 'upright_piano',
      name: 'Upright piano',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['acoustic piano'],
    ),
    (
      id: 'synthesizer',
      name: 'Synthesizer',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['synth'],
    ),
    (
      id: 'organ',
      name: 'Organ / Hammond',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['organ', 'hammond', 'hammond organ'],
    ),
    (
      id: 'rhodes',
      name: 'Rhodes',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['electric piano', 'fender rhodes'],
    ),
    (
      id: 'accordion',
      name: 'Accordion',
      icon: '🎹',
      category: 'Keys',
      brandable: false,
      aliases: ['squeezebox'],
    ),
    (
      id: 'keyboard_stand',
      name: 'Keyboard stand',
      icon: '🪑',
      category: 'Keys',
      brandable: false,
      aliases: ['keys stand', 'x stand'],
    ),
    (
      id: 'keytar',
      name: 'Keytar',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['shoulder keyboard'],
    ),
    (
      id: 'midi_controller',
      name: 'MIDI controller',
      icon: '🎹',
      category: 'Keys',
      brandable: true,
      aliases: ['controller keyboard', 'midi keyboard'],
    ),
    (
      id: 'violin',
      name: 'Violin',
      icon: '🎻',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['fiddle'],
    ),
    (
      id: 'viola',
      name: 'Viola',
      icon: '🎻',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: [],
    ),
    (
      id: 'cello',
      name: 'Cello',
      icon: '🎻',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['violoncello'],
    ),
    (
      id: 'harp',
      name: 'Harp',
      icon: '🎻',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['concert harp'],
    ),
    (
      id: 'trumpet',
      name: 'Trumpet',
      icon: '🎺',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['horn'],
    ),
    (
      id: 'trombone',
      name: 'Trombone',
      icon: '🎺',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['bone'],
    ),
    (
      id: 'saxophone',
      name: 'Saxophone',
      icon: '🎷',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['sax'],
    ),
    (
      id: 'tuba',
      name: 'Tuba',
      icon: '🎺',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['bass tuba'],
    ),
    (
      id: 'french_horn',
      name: 'French horn',
      icon: '🎺',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['horn'],
    ),
    (
      id: 'flute',
      name: 'Flute',
      icon: '🪈',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['concert flute'],
    ),
    (
      id: 'clarinet',
      name: 'Clarinet',
      icon: '🎷',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['clarionet'],
    ),
    (
      id: 'harmonica',
      name: 'Harmonica',
      icon: '🪈',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['blues harp', 'mouth organ'],
    ),
    (
      id: 'bagpipes',
      name: 'Bagpipes',
      icon: '🪈',
      category: 'Strings, brass & wind',
      brandable: false,
      aliases: ['pipes'],
    ),
    (
      id: 'vocal_mic',
      name: 'Vocal mic',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['vocal microphone', 'singing mic'],
    ),
    (
      id: 'wireless_mic',
      name: 'Wireless mic',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['radio mic', 'cordless microphone'],
    ),
    (
      id: 'headset_mic',
      name: 'Headset mic',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['headworn mic', 'headset microphone'],
    ),
    (
      id: 'mic_stand',
      name: 'Mic stand',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['microphone stand', 'boom stand'],
    ),
    (
      id: 'instrument_mic',
      name: 'Instrument mic',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['instrument microphone'],
    ),
    (
      id: 'drum_mic_set',
      name: 'Drum mic set',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['drum microphones', 'drum mic kit'],
    ),
    (
      id: 'overhead_mic',
      name: 'Overhead mic',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['overhead microphone', 'drum overhead'],
    ),
    (
      id: 'talkback_mic',
      name: 'Talkback mic',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['talkback microphone'],
    ),
    (
      id: 'pop_filter',
      name: 'Pop filter',
      icon: '🎤',
      category: 'Vocals & mics',
      brandable: false,
      aliases: ['pop shield', 'pop screen'],
    ),
    (
      id: 'guitar_amp',
      name: 'Guitar amp',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['guitar amplifier'],
    ),
    (
      id: 'guitar_cab',
      name: 'Guitar cab',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['guitar cabinet', 'speaker cabinet'],
    ),
    (
      id: 'bass_amp',
      name: 'Bass amp',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['bass amplifier'],
    ),
    (
      id: 'bass_cab',
      name: 'Bass cab',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['bass cabinet'],
    ),
    (
      id: 'combo_amp',
      name: 'Combo amp',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['combo amplifier'],
    ),
    (
      id: 'acoustic_amp',
      name: 'Acoustic amp',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['acoustic guitar amp'],
    ),
    (
      id: 'keyboard_amp',
      name: 'Keyboard amp',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['keys amp'],
    ),
    (
      id: 'amp_head',
      name: 'Amp head',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['amplifier head'],
    ),
    (
      id: 'isolation_cab',
      name: 'Isolation cab',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['iso cab', 'isolation cabinet'],
    ),
    (
      id: 'leslie_cabinet',
      name: 'Leslie cabinet',
      icon: '🔊',
      category: 'Amps & cabs',
      brandable: true,
      aliases: ['leslie', 'rotary speaker'],
    ),
    (
      id: 'monitor_wedge',
      name: 'Monitor wedge',
      icon: '🔊',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['floor monitor', 'stage monitor', 'wedge'],
    ),
    (
      id: 'side_fill',
      name: 'Side fill',
      icon: '🔊',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['sidefill', 'side fill monitor'],
    ),
    (
      id: 'pa_speaker',
      name: 'PA speaker',
      icon: '🔊',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['main speaker', 'house speaker'],
    ),
    (
      id: 'subwoofer',
      name: 'Subwoofer',
      icon: '🔊',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['sub', 'bass speaker'],
    ),
    (
      id: 'foh_mixer',
      name: 'Front-of-house mixer',
      icon: '🎚️',
      category: 'Monitoring & PA',
      brandable: true,
      aliases: ['foh mixer', 'front of house console'],
    ),
    (
      id: 'monitor_mixer',
      name: 'Monitor mixer',
      icon: '🎚️',
      category: 'Monitoring & PA',
      brandable: true,
      aliases: ['monitor console', 'monitor desk'],
    ),
    (
      id: 'stage_box',
      name: 'Stage box',
      icon: '🔌',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['stagebox', 'input box'],
    ),
    (
      id: 'di_box',
      name: 'DI box',
      icon: '🔌',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['direct box', 'direct injection box'],
    ),
    (
      id: 'snake',
      name: 'Snake',
      icon: '🔌',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['audio snake', 'multicore'],
    ),
    (
      id: 'iem_transmitter',
      name: 'IEM transmitter',
      icon: '🔊',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['in-ear transmitter', 'wireless monitor transmitter'],
    ),
    (
      id: 'in_ear_monitor_pack',
      name: 'In-ear monitor pack',
      icon: '🔊',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['iem pack', 'bodypack receiver'],
    ),
    (
      id: 'drum_fill',
      name: 'Drum fill',
      icon: '🔊',
      category: 'Monitoring & PA',
      brandable: false,
      aliases: ['drum monitor', 'drum sub'],
    ),
    (
      id: 'dj_controller',
      name: 'DJ controller',
      icon: '🎚️',
      category: 'DJ & electronic',
      brandable: true,
      aliases: ['dj deck', 'decks'],
    ),
    (
      id: 'turntable',
      name: 'Turntable',
      icon: '🎚️',
      category: 'DJ & electronic',
      brandable: true,
      aliases: ['record player', 'vinyl deck'],
    ),
    (
      id: 'cdj',
      name: 'CDJ',
      icon: '🎚️',
      category: 'DJ & electronic',
      brandable: true,
      aliases: ['media player', 'dj player'],
    ),
    (
      id: 'laptop',
      name: 'Laptop',
      icon: '🎛️',
      category: 'DJ & electronic',
      brandable: false,
      aliases: ['computer', 'macbook'],
    ),
    (
      id: 'audio_interface',
      name: 'Audio interface',
      icon: '🎛️',
      category: 'DJ & electronic',
      brandable: false,
      aliases: ['sound card', 'usb interface'],
    ),
    (
      id: 'sampler_drum_machine',
      name: 'Sampler / drum machine',
      icon: '🎛️',
      category: 'DJ & electronic',
      brandable: false,
      aliases: ['sampler', 'drum machine', 'groovebox'],
    ),
    (
      id: 'looper',
      name: 'Looper',
      icon: '🎛️',
      category: 'DJ & electronic',
      brandable: false,
      aliases: ['loop station', 'loop pedal'],
    ),
    (
      id: 'effects_rack',
      name: 'Effects rack',
      icon: '🎛️',
      category: 'DJ & electronic',
      brandable: false,
      aliases: ['fx rack', 'outboard rack'],
    ),
    (
      id: 'pedalboard',
      name: 'Pedalboard',
      icon: '🎛️',
      category: 'DJ & electronic',
      brandable: false,
      aliases: ['pedal board', 'effects pedals'],
    ),
    (
      id: 'backing_track_player',
      name: 'Backing track player',
      icon: '🎛️',
      category: 'DJ & electronic',
      brandable: false,
      aliases: ['playback rig', 'tracks player'],
    ),
    (
      id: 'music_stand',
      name: 'Music stand',
      icon: '🪑',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['sheet music stand'],
    ),
    (
      id: 'mic_riser',
      name: 'Mic riser',
      icon: '🪑',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['vocal riser'],
    ),
    (
      id: 'stool',
      name: 'Stool',
      icon: '🪑',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['chair', 'seat'],
    ),
    (
      id: 'set_list_holder',
      name: 'Set list holder',
      icon: '🪑',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['setlist holder', 'tablet holder'],
    ),
    (
      id: 'water_towels_table',
      name: 'Water / towels table',
      icon: '🪑',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['water table', 'towel table'],
    ),
    (
      id: 'lighting_rig',
      name: 'Lighting rig',
      icon: '💡',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['stage lights', 'lighting truss'],
    ),
    (
      id: 'haze_machine',
      name: 'Haze machine',
      icon: '💡',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['hazer', 'fog machine'],
    ),
    (
      id: 'backdrop',
      name: 'Backdrop',
      icon: '🎬',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['stage backdrop', 'drape'],
    ),
    (
      id: 'banner',
      name: 'Banner',
      icon: '🎬',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['band banner', 'scrim'],
    ),
    (
      id: 'power_strip',
      name: 'Power strip',
      icon: '🔌',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['extension lead', 'power bar'],
    ),
    (
      id: 'cable_ramp',
      name: 'Cable ramp',
      icon: '🔌',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['cable protector', 'cable cover'],
    ),
    (
      id: 'gaffer_tape_box',
      name: 'Gaffer tape box',
      icon: '🔌',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['gaff tape', 'tape box'],
    ),
    (
      id: 'guitar_tech_station',
      name: 'Guitar tech station',
      icon: '🪑',
      category: 'Stage & misc',
      brandable: false,
      aliases: ['tech station', 'guitar workbench'],
    ),
  ];

  static const Map<String, List<String>> _brands = {
    'Amps & cabs': [
      'Marshall',
      'Orange',
      'Vox AC30',
      'Mesa Boogie',
      'Fender Twin',
      'Ampeg SVT',
      'Roland JC-120',
      'Hartke',
      'Blackstar',
      'Laney',
      'Peavey',
    ],
    'Drums & percussion': [
      'Pearl',
      'Tama',
      'Ludwig',
      'DW',
      'Yamaha',
      'Gretsch',
      'Sonor',
    ],
    'Keys': ['Nord', 'Roland', 'Korg', 'Yamaha', 'Moog', 'Hammond'],
    'DJ & electronic': [
      'Pioneer',
      'Technics',
      'Denon',
      'Native Instruments',
    ],
    'Monitoring & PA': [
      'QSC',
      'RCF',
      'd&b audiotechnik',
      'Behringer',
      'Allen & Heath',
      'Yamaha',
    ],
  };

  static const Map<String, List<String>> _roleSuggestions = {
    'drummer': ['drum_kit', 'drum_throne', 'monitor_wedge'],
    'percussionist': ['drum_kit', 'drum_throne', 'monitor_wedge'],
    'bassist': ['bass_guitar', 'bass_amp', 'di_box'],
    'guitarist': ['electric_guitar', 'guitar_amp', 'guitar_stand'],
    'keyboardist': ['keyboard', 'keyboard_stand', 'di_box'],
    'pianist': ['keyboard', 'keyboard_stand', 'di_box'],
    'vocalist': ['vocal_mic', 'mic_stand', 'monitor_wedge'],
    'lead_vocalist': ['vocal_mic', 'mic_stand', 'monitor_wedge'],
    'backing_vocalist': ['vocal_mic', 'mic_stand', 'monitor_wedge'],
    'backup_singer': ['vocal_mic', 'mic_stand', 'monitor_wedge'],
    'rapper': ['vocal_mic', 'mic_stand', 'monitor_wedge'],
    'mc': ['vocal_mic', 'mic_stand', 'monitor_wedge'],
    'dj': ['dj_controller', 'laptop'],
    'sound_engineer': ['foh_mixer', 'pa_speaker'],
    'audio_engineer': ['foh_mixer', 'pa_speaker'],
    'saxophonist': ['saxophone', 'instrument_mic'],
    'violinist': ['violin', 'di_box'],
    'cellist': ['cello', 'di_box'],
  };

  /// Finds entries whose name or aliases contain [query].
  ///
  /// Name-prefix matches are returned first; order is otherwise unchanged.
  static List<GearEntry> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return catalog;

    final prefix = <GearEntry>[];
    final rest = <GearEntry>[];
    for (final entry in catalog) {
      final name = entry.name.toLowerCase();
      if (!name.contains(needle) &&
          !entry.aliases.any((alias) => alias.contains(needle))) {
        continue;
      }
      (name.startsWith(needle) ? prefix : rest).add(entry);
    }
    return [...prefix, ...rest];
  }

  /// Returns the catalog entry with [id], or `null` when it is unknown.
  static GearEntry? byId(String id) {
    for (final entry in catalog) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  /// Resolves an icon for a legacy stage placement label.
  ///
  /// Matching checks exact names, then aliases, then name substrings.
  static String iconFor(String label, {String kind = 'equipment'}) {
    // People never resolve against the gear catalog — a member called "Vi"
    // would otherwise substring-match "Violin" and get an instrument icon.
    if (kind == 'member') return '🧑';
    final needle = label.trim().toLowerCase();
    if (needle.isNotEmpty) {
      for (final entry in catalog) {
        if (entry.name.toLowerCase() == needle) return entry.icon;
      }
      for (final entry in catalog) {
        if (entry.aliases.contains(needle)) return entry.icon;
      }
      for (final entry in catalog) {
        if (entry.name.toLowerCase().contains(needle)) return entry.icon;
      }
    }
    return kind == 'member' ? '🧑' : '🔊';
  }

  /// Returns the suggested brands for [category], or an empty list.
  static List<String> brandsFor(String category) =>
      _brands[category] ?? const [];

  /// Returns de-duplicated catalog ids suggested by normalized band roles.
  ///
  /// A monitor wedge and power strip are always appended when not already
  /// suggested by a role.
  static List<String> suggestedFor(Iterable<String> roleKeys) {
    final result = <String>[];
    final seen = <String>{};

    void add(String id) {
      if (seen.add(id) && byId(id) != null) result.add(id);
    }

    for (final role in roleKeys) {
      final key = role
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[\s-]+'), '_');
      (_roleSuggestions[key] ?? const <String>[]).forEach(add);
    }
    add('monitor_wedge');
    add('power_strip');
    return result;
  }
}
