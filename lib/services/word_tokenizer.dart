import 'package:characters/characters.dart';

/// Снимает знаки препинания и символы с **краёв** токена (кавычки, скобки и т.д.).
/// Внутри слова апостроф в *don't* и дефис в *well-known* сохраняются.
final _edgePunctAndSymbols = RegExp(
  r'^[\p{P}\p{S}]+|[\p{P}\p{S}]+$',
  unicode: true,
);

String stripPunctuationEdges(String token) {
  return token.replaceAll(_edgePunctAndSymbols, '');
}

/// Разбивает текст на слова для RSVP: пробелы + очистка краёв от пунктуации.
List<String> tokenizeForRsvp(String text) {
  final normalized = text.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  if (normalized.isEmpty) return [];
  final out = <String>[];
  for (final part in normalized.split(RegExp(r'\s+'))) {
    if (part.isEmpty) continue;
    final cleaned = stripPunctuationEdges(part);
    if (cleaned.isEmpty) continue;
    out.add(cleaned);
  }
  return List<String>.unmodifiable(out);
}

/// Индекс **опорной буквы** (ORP, optimal recognition point) по графемам, 0-based.
/// Та же идея, что в Spritz / скорочтении: глаз фиксируется на одной позиции в слове.
int optimalRecognitionPointIndex(String word) {
  final len = word.characters.length;
  if (len <= 0) return 0;
  const orpForLength = [
    0, 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 4,
  ];
  if (len <= orpForLength.length) {
    return orpForLength[len - 1];
  }
  final extra = len - orpForLength.length;
  return (4 + (extra * 2 ~/ 5)).clamp(0, len - 1);
}
