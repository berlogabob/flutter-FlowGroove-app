// Conditional export: real iframe on web, fallback widget elsewhere.
export 'docs_panel_stub.dart'
  if (dart.library.html) 'docs_panel_web.dart';
