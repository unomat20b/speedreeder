import 'package:html/parser.dart' as html_parser;

import 'book_navigation.dart';

/// Ошибка разбора EPUB (повреждённый файл или неподдерживаемая структура).
class EpubExtractException implements Exception {
  EpubExtractException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Результат импорта EPUB для RSVP.
class EpubImportPayload {
  EpubImportPayload({
    required this.plainText,
    this.metadataTitle,
    this.navigation,
  });

  final String plainText;
  final String? metadataTitle;
  final List<BookNavEntry>? navigation;
}

/// Видимый текст из фрагмента XHTML/HTML (удобно для тестов).
String epubHtmlToPlainText(String? html) {
  if (html == null || html.isEmpty) return '';
  final fragment = html_parser.parseFragment(html);
  var t = fragment.text?.trim() ?? '';
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t.trim();
}
