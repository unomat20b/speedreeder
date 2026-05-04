import 'book_navigation.dart';
import 'pdf_import_payload.dart';
import 'word_tokenizer.dart';

/// Собирает [PdfImportPayload] из текста и смещений начала страниц (в символах).
PdfImportPayload buildPdfImportPayload(
  String plain,
  List<({int page, int charOffset})> anchors,
) {
  final nav = <BookNavEntry>[];
  for (final a in anchors) {
    final o = a.charOffset.clamp(0, plain.length);
    final w = wordIndexAtSourceOffset(plain, o);
    if (nav.isNotEmpty && nav.last.startWordIndex == w) continue;
    nav.add(BookNavEntry(
      label: '',
      startWordIndex: w,
      pageNumber: a.page,
    ));
  }
  return PdfImportPayload(
    plainText: plain,
    navigation: nav.isEmpty ? const [] : nav,
  );
}
