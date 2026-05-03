import 'package:flutter_test/flutter_test.dart';
import 'package:speedreeder/services/epub_text_extractor.dart';

void main() {
  group('epubHtmlToPlainText', () {
    test('strips tags and keeps words', () {
      expect(
        epubHtmlToPlainText('<p>Hello <b>world</b>.</p>'),
        'Hello world.',
      );
    });

    test('empty and null-like', () {
      expect(epubHtmlToPlainText(''), '');
      expect(epubHtmlToPlainText(null), '');
    });

    test('normalizes spaces', () {
      expect(
        epubHtmlToPlainText('  a   \n  b  '),
        'a b',
      );
    });
  });
}
