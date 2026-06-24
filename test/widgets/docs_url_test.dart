import 'package:flowgroove/widgets/desktop_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('docs url resolves as sibling of app base on any host', () {
    expect(
      resolveDocsUrl(Uri.parse('https://flowgroove.app/app/#/main/home')),
      'https://flowgroove.app/faq/embed.html',
    );
    expect(
      resolveDocsUrl(
        Uri.parse('https://berlogabob.github.io/flutter-FlowGroove-app/app/#/x'),
      ),
      'https://berlogabob.github.io/flutter-FlowGroove-app/faq/embed.html',
    );
  });
}
