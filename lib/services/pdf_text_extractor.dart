import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdfrx/pdfrx.dart';

import 'pdf_import_payload.dart';
import 'pdf_js_bridge_export.dart';
import 'pdf_nav_build.dart';

/// Собирает plain text со всех страниц PDF: на вебе сначала PDF.js (как у shir-man),
/// затем PDFium/pdfrx; на остальных платформах только pdfrx.
Future<PdfImportPayload> extractPdfForSpeedreader(
  Uint8List bytes, {
  String? sourceName,
}) async {
  if (bytes.isEmpty) {
    return const PdfImportPayload(plainText: '');
  }

  if (kIsWeb) {
    final jsPayload = await tryExtractPdfWithPdfJs(bytes);
    if (jsPayload != null && jsPayload.plainText.trim().isNotEmpty) {
      return jsPayload;
    }
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
    return buildPdfImportPayload(plain, anchors);
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
