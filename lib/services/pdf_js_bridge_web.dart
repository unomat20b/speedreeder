// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'pdf_import_payload.dart';
import 'pdf_nav_build.dart';

Future<PdfImportPayload?> tryExtractPdfWithPdfJs(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  await _waitForPdfJsBridge();
  final fn = js_util.getProperty(html.window, '__speedreederExtractPdfJson');
  if (fn == null) return null;
  try {
    final b64 = base64Encode(bytes);
    final raw = await js_util.promiseToFuture<Object?>(
      js_util.callMethod(fn, 'call', [html.window, b64]),
    );
    if (raw is! String) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final pagesRaw = decoded['pages'];
    if (pagesRaw is! List) return null;
    final pages = pagesRaw.map((e) => e?.toString() ?? '').toList();

    final buf = StringBuffer();
    final anchors = <({int page, int charOffset})>[];
    var pageNum = 0;
    for (final rawPage in pages) {
      pageNum++;
      var s = rawPage.replaceAll('\r\n', '\n').trim();
      if (s.isEmpty) continue;
      anchors.add((page: pageNum, charOffset: buf.length));
      if (buf.isNotEmpty) buf.writeln();
      buf.write(s);
    }
    final plain = buf.toString();
    if (plain.trim().isEmpty) return null;
    return buildPdfImportPayload(plain, anchors);
  } catch (_) {
    return null;
  }
}

Future<void> _waitForPdfJsBridge() async {
  for (var i = 0; i < 400; i++) {
    if (js_util.hasProperty(html.window, '__speedreederExtractPdfJson')) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}
