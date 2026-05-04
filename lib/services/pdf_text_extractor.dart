import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdfrx/pdfrx.dart';

import 'book_navigation.dart';
import 'word_tokenizer.dart';

/// Текст PDF и навигация по страницам (для читалки).
class PdfImportPayload {
  const PdfImportPayload({
    required this.plainText,
    this.navigation = const [],
  });

  final String plainText;
  final List<BookNavEntry> navigation;
}

/// Собирает plain text со всех страниц PDF (через PDFium / на вебе — WASM).
Future<PdfImportPayload> extractPdfForSpeedreader(
  Uint8List bytes, {
  String? sourceName,
}) async {
  if (bytes.isEmpty) {
    return const PdfImportPayload(plainText: '');
  }

  PdfDocument? doc;
  try {
    doc = await PdfDocument.openData(
      bytes,
      sourceName: sourceName ?? 'import.pdf',
      allowDataOwnershipTransfer: kIsWeb,
    );
    await doc.loadPagesProgressively();

    final buf = StringBuffer();
    final anchors = <({int page, int charOffset})>[];

    for (var i = 0; i < doc.pages.length; i++) {
      final page = doc.pages[i];
      anchors.add((page: page.pageNumber, charOffset: buf.length));
      final pageText = await page.loadText();
      var s = pageText.fullText.replaceAll('\r\n', '\n').trim();
      if (s.isEmpty) continue;
      if (buf.isNotEmpty) buf.writeln();
      buf.write(s);
    }

    final plain = buf.toString();
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

    return PdfImportPayload(plainText: plain, navigation: nav);
  } finally {
    if (doc != null) {
      await doc.dispose();
    }
  }
}

/// Обратная совместимость: только строка текста.
Future<String> extractPlainTextFromPdfBytes(
  Uint8List bytes, {
  String? sourceName,
}) async {
  final p = await extractPdfForSpeedreader(bytes, sourceName: sourceName);
  return p.plainText;
}
