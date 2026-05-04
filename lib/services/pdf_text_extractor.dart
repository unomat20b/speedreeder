import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdfrx/pdfrx.dart';

/// Собирает plain text со всех страниц PDF (через PDFium / на вебе — WASM).
Future<String> extractPlainTextFromPdfBytes(
  Uint8List bytes, {
  String? sourceName,
}) async {
  if (bytes.isEmpty) return '';

  PdfDocument? doc;
  try {
    doc = await PdfDocument.openData(
      bytes,
      sourceName: sourceName ?? 'import.pdf',
      allowDataOwnershipTransfer: kIsWeb,
    );
    await doc.loadPagesProgressively();

    final buf = StringBuffer();
    for (final page in doc.pages) {
      final pageText = await page.loadText();
      var s = pageText.fullText.replaceAll('\r\n', '\n').trim();
      if (s.isEmpty) continue;
      if (buf.isNotEmpty) buf.writeln();
      buf.write(s);
    }
    return buf.toString();
  } finally {
    if (doc != null) {
      await doc.dispose();
    }
  }
}
