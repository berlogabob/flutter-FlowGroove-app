import 'package:flowgroove/utils/member_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('memberLabel', () {
    test('returns trimmed displayName if non-empty', () {
      expect(
        memberLabel(displayName: 'Alice', email: 'alice@example.com'),
        equals('Alice'),
      );
    });

    test('returns email if displayName is null', () {
      expect(memberLabel(email: 'bob@example.com'), equals('bob@example.com'));
    });

    test('returns email if displayName is empty string', () {
      expect(
        memberLabel(displayName: '', email: 'charlie@example.com'),
        equals('charlie@example.com'),
      );
    });

    test('returns email if displayName is whitespace-only', () {
      expect(
        memberLabel(displayName: '   ', email: 'dave@example.com'),
        equals('dave@example.com'),
      );
    });

    test('returns "Invited member" if both displayName and email are null', () {
      expect(memberLabel(), equals('Invited member'));
    });

    test(
      'returns "Invited member" if both displayName and email are empty',
      () {
        expect(
          memberLabel(displayName: '', email: ''),
          equals('Invited member'),
        );
      },
    );

    test('returns trimmed displayName with leading/trailing whitespace', () {
      expect(
        memberLabel(displayName: '  Eve  ', email: 'eve@example.com'),
        equals('Eve'),
      );
    });
  });
}
