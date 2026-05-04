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

/// UTF-16 диапазоны RSVP-слов в исходном [sourceText] (те же границы, что у [tokenizeForRsvp]).
///
/// Для каждого токена — интервал `[start, endExclusive)` по «очищенному» ядру
/// внутри пробельно-разделённого фрагмента (без кавычек/пунктуации на краях).
List<({int start, int endExclusive})> rsvpWordUtf16Spans(String sourceText) {
  final spans = <({int start, int endExclusive})>[];
  final n = sourceText.replaceAll(RegExp(r'\r\n?'), '\n');
  var i = 0;
  final lead = RegExp(r'^\s*').firstMatch(n);
  if (lead != null) i = lead.end;
  while (i < n.length) {
    final ws = RegExp(r'^\s+').firstMatch(n.substring(i));
    if (ws != null) {
      i += ws.end;
      continue;
    }
    if (i >= n.length) break;
    final runStart = i;
    final runMatch = RegExp(r'^\S+').firstMatch(n.substring(i));
    if (runMatch == null) break;
    final runEnd = i + runMatch.end;
    final run = n.substring(runStart, runEnd);
    final cleaned = stripPunctuationEdges(run);
    if (cleaned.isEmpty) {
      i = runEnd;
      continue;
    }
    final leadStrip = RegExp(r'^[\p{P}\p{S}]+', unicode: true).firstMatch(run);
    final leadLen = leadStrip?.end ?? 0;
    final tailStrip = RegExp(r'[\p{P}\p{S}]+$', unicode: true).firstMatch(run);
    final coreEnd = tailStrip != null ? tailStrip.start : run.length;
    final coreStart = runStart + leadLen;
    final coreEndAbs = runStart + coreEnd;
    if (coreStart < coreEndAbs) {
      spans.add((start: coreStart, endExclusive: coreEndAbs));
    }
    i = runEnd;
  }
  return spans;
}

/// Сколько RSVP-слов попадает в префикс `text.substring(0, utf16Offset)` (как у [tokenizeForRsvp]).
///
/// Используется для привязки выделения в исходном тексте к индексу слова и для навигации.
int wordIndexAtSourceOffset(String text, int utf16Offset) {
  if (utf16Offset <= 0) return 0;
  final len = text.length;
  if (utf16Offset >= len) {
    return tokenizeForRsvp(text).length;
  }
  return tokenizeForRsvp(text.substring(0, utf16Offset)).length;
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
