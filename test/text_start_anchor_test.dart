import 'package:flutter_test/flutter_test.dart';
import 'package:speedreeder/services/text_start_anchor.dart';

void main() {
  test('empty anchor returns full text', () {
    expect(sliceTextFromAnchor('abc def', ''), 'abc def');
    expect(sliceTextFromAnchor('abc def', '   '), 'abc def');
  });

  test('slices from first occurrence inclusive', () {
    expect(
      sliceTextFromAnchor('intro Глава один текст', 'Глава один'),
      'Глава один текст',
    );
  });

  test('not found returns null', () {
    expect(sliceTextFromAnchor('abc', 'zzz'), isNull);
  });
}
