import 'package:flutter_test/flutter_test.dart';
import 'package:speedreeder/services/book_navigation.dart';
import 'package:speedreeder/services/word_tokenizer.dart';

void main() {
  group('tokenizeForRsvp', () {
    test('splits words', () {
      expect(tokenizeForRsvp('a b c'), ['a', 'b', 'c']);
      expect(tokenizeForRsvp('  hello   world  '), ['hello', 'world']);
      expect(tokenizeForRsvp(''), isEmpty);
    });

    test('strips edge punctuation', () {
      expect(tokenizeForRsvp('Hello, world!'), ['Hello', 'world']);
      expect(tokenizeForRsvp('«да».'), ['да']);
      expect(tokenizeForRsvp("don't."), ["don't"]);
      expect(tokenizeForRsvp('...'), isEmpty);
    });
  });

  group('optimalRecognitionPointIndex', () {
    test('spritz-like pivots', () {
      expect(optimalRecognitionPointIndex('a'), 0);
      expect(optimalRecognitionPointIndex('ab'), 0);
      expect(optimalRecognitionPointIndex('abc'), 1);
      expect(optimalRecognitionPointIndex('abcd'), 1);
      expect(optimalRecognitionPointIndex('abcde'), 2);
      expect(optimalRecognitionPointIndex('абвгд'), 2);
    });
  });

  group('wordIndexAtSourceOffset', () {
    test('matches prefix token count', () {
      const t = 'one two three four five';
      expect(wordIndexAtSourceOffset(t, 0), 0);
      expect(wordIndexAtSourceOffset(t, t.length), tokenizeForRsvp(t).length);
      expect(wordIndexAtSourceOffset(t, 4), 1);
    });
  });

  group('BookNavEntry.afterCrop', () {
    test('shifts indices after substring import', () {
      const text = 'one two three four five';
      final nav = [
        BookNavEntry(label: 'here', startWordIndex: 3),
      ];
      final adj = BookNavEntry.afterCrop(text, nav, 4);
      expect(adj, isNotNull);
      expect(adj!.single.startWordIndex, 2);
    });
  });
}
