import 'book_navigation.dart';

/// Текст PDF и навигация по страницам (для читалки).
class PdfImportPayload {
  const PdfImportPayload({
    required this.plainText,
    this.navigation = const [],
  });

  final String plainText;
  final List<BookNavEntry> navigation;
}
