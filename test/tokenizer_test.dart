import 'package:flutter_test/flutter_test.dart';
import 'package:speedreeder/services/word_tokenizer.dart';

void main() {
  test('tokenize splits words', () {
    expect(tokenizeForRsvp('a b c'), ['a', 'b', 'c']);
    expect(tokenizeForRsvp('  hello   world  '), ['hello', 'world']);
    expect(tokenizeForRsvp(''), isEmpty);
  });
}
