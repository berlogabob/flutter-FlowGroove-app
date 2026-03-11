// Conditional export for web version loader
export 'web_version_loader_stub.dart'
  if (dart.library.html) 'web_version_loader.dart';
