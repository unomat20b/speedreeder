import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';

/// Декодирует байты plain-text импорта (.txt): UTF-8 (включая BOM), иначе
/// эвристика между Windows-1251, Windows-1252, KOI8-R и Latin-1.
String decodeImportTextBytes(Uint8List raw) {
  if (raw.isEmpty) return '';

  var bytes = raw;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    bytes = bytes.sublist(3);
    final bomUtf8 = _tryUtf8Strict(bytes);
    if (bomUtf8 != null) return bomUtf8;
    return _decodeBestSingleByte(bytes);
  }

  final utf8Candidate = _tryUtf8Strict(bytes);
  if (utf8Candidate != null) {
    if (_utf8ProbablyMojibake(utf8Candidate, bytes)) {
      final better = _decodeBestSingleByte(bytes);
      if (_textQualityScore(better) > _textQualityScore(utf8Candidate)) {
        return better;
      }
    }
    return utf8Candidate;
  }

  return _decodeBestSingleByte(bytes);
}

String? _tryUtf8Strict(Uint8List bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    return null;
  }
}

/// Когда UTF-8 «валиден», но похож на типичную путаницу с однобайтовой кириллицей.
bool _utf8ProbablyMojibake(String s, Uint8List bytes) {
  if (s.contains('\uFFFD')) return true;
  if (bytes.length < 64) return false;

  final cyr = RegExp(r'[А-Яа-яЁё]').allMatches(s).length;
  final latLetters = RegExp(r'[A-Za-z]').allMatches(s).length;
  if (cyr > 0) return false;

  final as1251 = const Windows1251Codec(allowInvalid: true).decode(bytes);
  final cyr1251 = RegExp(r'[А-Яа-яЁё]').allMatches(as1251).length;
  return cyr1251 >= 8 && cyr1251 > latLetters;
}

String _decodeBestSingleByte(Uint8List bytes) {
  final candidates = <String>[
    const Windows1251Codec(allowInvalid: true).decode(bytes),
    const Windows1252Codec(allowInvalid: true).decode(bytes),
    const Koi8rCodec(allowInvalid: true).decode(bytes),
    latin1.decode(bytes),
  ];

  String best = candidates.first;
  var bestScore = _textQualityScore(best);
  for (var i = 1; i < candidates.length; i++) {
    final sc = _textQualityScore(candidates[i]);
    if (sc > bestScore) {
      bestScore = sc;
      best = candidates[i];
    }
  }
  return best;
}

int _textQualityScore(String s) {
  if (s.isEmpty) return -1000000;
  var score = 0;
  for (final r in s.runes) {
    if (r == 0xFFFD) {
      score -= 10;
    } else if (r == 0x00) {
      score -= 5;
    } else if (r < 32 && r != 10 && r != 13 && r != 9) {
      score -= 1;
    } else if ((r >= 0x0400 && r <= 0x04FF) || r == 0x0451 || r == 0x0401) {
      score += 4;
    } else if (r >= 0x0020 && r <= 0x007E) {
      score += 1;
    } else if (r >= 0x80) {
      score += 1;
    }
  }
  return score;
}

int importTextQualityScore(String s) => _textQualityScore(s);

bool looksLikeMojibakeText(String s) {
  if (s.isEmpty) return false;
  if (s.contains('\uFFFD')) return true;

  final cyr = RegExp(r'[А-Яа-яЁё]').allMatches(s).length;
  if (cyr >= 8) return false;

  // Типичные следы UTF-8/Windows-1251 путаницы: Ð, Ñ, Ã, Â.
  final mojibake = RegExp(r'[ÐÑÃÂ]').allMatches(s).length;
  final letters = RegExp(r'[\p{L}]', unicode: true).allMatches(s).length;
  return mojibake >= 8 && mojibake * 5 > letters;
}

/// Файл похож на PDF: ищем сигнатуру `%PDF` в первых [scan] байтах (допускается мусор в начале).
bool looksLikePdfBytes(Uint8List bytes, {int scan = 4096}) {
  final n = bytes.length < scan ? bytes.length : scan;
  if (n < 4) return false;
  for (var i = 0; i <= n - 4; i++) {
    if (bytes[i] == 0x25 &&
        bytes[i + 1] == 0x50 &&
        bytes[i + 2] == 0x44 &&
        bytes[i + 3] == 0x46) {
      return true;
    }
  }
  return false;
}
