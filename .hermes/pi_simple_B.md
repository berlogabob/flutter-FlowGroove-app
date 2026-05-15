Create a Dart test file at test/repositories/firestore_song_repository_integration_test.dart.
Write a single test called 'watchSongs merges legacy and v2 songs' that:
- Sets up a mock user.
- Seeds a legacy song via direct Firestore write (bypass repository) without schemaVersion.
- Seeds a v2 library song with a canonical reference and delta.
- Calls repository.watchSongs(uid) and collects first emission.
- Expects both songs present, with v2 merged fields.
Include necessary imports and main().

Do NOT attempt to run tests. Just write the file.

Then output: "File written."