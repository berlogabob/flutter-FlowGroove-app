/// What a launched pad does when its section ends.
enum PlayMode {
  /// Play the section once, then stop the backing.
  once,

  /// Repeat the section until another pad or Stop.
  loop,

  /// Continue through the following sections to the end of the song.
  song;

  String get label => switch (this) {
    PlayMode.once => 'Once',
    PlayMode.loop => 'Loop',
    PlayMode.song => 'Song',
  };

  /// Order the transport button cycles through.
  PlayMode get next => switch (this) {
    PlayMode.once => PlayMode.loop,
    PlayMode.loop => PlayMode.song,
    PlayMode.song => PlayMode.once,
  };
}
