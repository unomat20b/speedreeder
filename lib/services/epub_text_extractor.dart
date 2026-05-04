import 'dart:typed_data';

import 'package:epubx/epubx.dart';

import 'book_navigation.dart';
import 'epub_common.dart';
import 'epub_zip_fallback.dart';
import 'text_import_encoding.dart';
import 'word_tokenizer.dart';

export 'epub_common.dart';

class _CharAnchor {
  _CharAnchor(this.label, this.charOffset);

  final String label;
  final int charOffset;
}

class _ExtractResult {
  _ExtractResult(this.text, this.anchors);

  final String text;
  final List<_CharAnchor> anchors;
}

List<BookNavEntry> _finalizeCharAnchors(String text, List<_CharAnchor> raw) {
  final out = <BookNavEntry>[];
  for (final r in raw) {
    final o = r.charOffset.clamp(0, text.length);
    final w = wordIndexAtSourceOffset(text, o);
    if (out.isNotEmpty && out.last.startWordIndex == w) continue;
    out.add(BookNavEntry(label: r.label, startWordIndex: w));
  }
  return out;
}

/// Читает EPUB из байтов и возвращает сплошной plain text по оглавлению, spine или всем HTML-файлам.
Future<EpubImportPayload> extractEpubForSpeedreader(List<int> bytes) async {
  if (bytes.isEmpty) {
    throw EpubExtractException('Файл EPUB пустой.');
  }

  final EpubBook book;
  try {
    book = await EpubReader.readBook(bytes);
  } catch (e) {
    final fb = await extractEpubZipFallback(Uint8List.fromList(bytes));
    if (fb != null && fb.plainText.trim().isNotEmpty) {
      return fb;
    }
    throw EpubExtractException('Не удалось разобрать EPUB: $e');
  }

  _ExtractResult? result = _plainFromChaptersWithNav(book.Chapters);
  if (result.text.trim().isEmpty) {
    result = _plainFromSpineWithNav(book);
  }
  if (result.text.trim().isEmpty) {
    result = _plainFromAllHtmlWithNav(book);
  }

  if (result.text.trim().isEmpty) {
    final fb = await extractEpubZipFallback(Uint8List.fromList(bytes));
    if (fb != null && fb.plainText.trim().isNotEmpty) {
      return fb;
    }
    throw EpubExtractException(
      'В EPUB не найдено текстового содержимого (проверьте формат книги).',
    );
  }

  if (looksLikeMojibakeText(result.text)) {
    final fb = await extractEpubZipFallback(Uint8List.fromList(bytes));
    if (fb != null &&
        fb.plainText.trim().isNotEmpty &&
        importTextQualityScore(fb.plainText) >
            importTextQualityScore(result.text)) {
      return fb;
    }
  }

  final meta = book.Title?.trim();
  final navList = result.anchors.isEmpty
      ? <BookNavEntry>[]
      : _finalizeCharAnchors(result.text, result.anchors);

  return EpubImportPayload(
    plainText: result.text,
    metadataTitle: (meta != null && meta.isNotEmpty) ? meta : null,
    navigation: navList.isEmpty ? null : navList,
  );
}

_ExtractResult _plainFromChaptersWithNav(List<EpubChapter>? chapters) {
  if (chapters == null || chapters.isEmpty) {
    return _ExtractResult('', []);
  }
  final buf = StringBuffer();
  final anchors = <_CharAnchor>[];
  var untitled = 0;

  void walk(EpubChapter ch) {
    untitled++;
    final title = ch.Title?.trim();
    final label = (title != null && title.isNotEmpty) ? title : '§ $untitled';
    anchors.add(_CharAnchor(label, buf.length));

    final plain = epubHtmlToPlainText(ch.HtmlContent);
    if (plain.isNotEmpty) {
      if (buf.isNotEmpty) buf.writeln();
      buf.write(plain);
    }
    for (final sub in ch.SubChapters ?? const <EpubChapter>[]) {
      walk(sub);
    }
  }

  for (final c in chapters) {
    walk(c);
  }
  return _ExtractResult(buf.toString(), anchors);
}

String _labelFromSpineHref(String href) {
  final parts = href.split('/');
  var name = parts.isNotEmpty ? parts.last : href;
  name = Uri.decodeFull(name);
  final dot = name.lastIndexOf('.');
  if (dot > 0) {
    name = name.substring(0, dot);
  }
  return name.isNotEmpty ? name : href;
}

_ExtractResult _plainFromSpineWithNav(EpubBook book) {
  final pkg = book.Schema?.Package;
  final spineItems = pkg?.Spine?.Items;
  final manifestItems = pkg?.Manifest?.Items;
  final htmlMap = book.Content?.Html;
  if (spineItems == null || manifestItems == null || htmlMap == null) {
    return _ExtractResult('', []);
  }

  final byId = <String, EpubManifestItem>{};
  for (final m in manifestItems) {
    final id = m.Id;
    if (id != null) byId[id] = m;
  }

  final buf = StringBuffer();
  final anchors = <_CharAnchor>[];
  for (final spine in spineItems) {
    final idRef = spine.IdRef;
    if (idRef == null) continue;
    final item = byId[idRef];
    final href = item?.Href;
    if (href == null) continue;
    anchors.add(_CharAnchor(_labelFromSpineHref(href), buf.length));
    final file = _lookupHtmlFile(htmlMap, href);
    final raw = file?.Content;
    if (raw == null || raw.isEmpty) continue;
    final plain = epubHtmlToPlainText(raw);
    if (plain.isEmpty) continue;
    if (buf.isNotEmpty) buf.writeln();
    buf.write(plain);
  }
  return _ExtractResult(buf.toString(), anchors);
}

_ExtractResult _plainFromAllHtmlWithNav(EpubBook book) {
  final htmlMap = book.Content?.Html;
  if (htmlMap == null || htmlMap.isEmpty) {
    return _ExtractResult('', []);
  }

  final keys = htmlMap.keys.toList()..sort();
  final buf = StringBuffer();
  final anchors = <_CharAnchor>[];
  for (final k in keys) {
    final lower = k.toLowerCase();
    if (lower.endsWith('.ncx')) continue;
    final f = htmlMap[k];
    final raw = f?.Content;
    if (raw == null || raw.isEmpty) continue;
    final plain = epubHtmlToPlainText(raw);
    if (plain.isEmpty) continue;
    anchors.add(_CharAnchor(_labelFromSpineHref(k), buf.length));
    if (buf.isNotEmpty) buf.writeln();
    buf.write(plain);
  }
  return _ExtractResult(buf.toString(), anchors);
}

EpubTextContentFile? _lookupHtmlFile(
  Map<String, EpubTextContentFile> htmlMap,
  String href,
) {
  if (htmlMap.containsKey(href)) return htmlMap[href];
  final decoded = Uri.decodeFull(href);
  if (htmlMap.containsKey(decoded)) return htmlMap[decoded];

  for (final entry in htmlMap.entries) {
    final k = entry.key;
    if (k.isEmpty) continue;
    if (k == href || k.endsWith('/$href') || href.endsWith(k)) {
      return entry.value;
    }
  }
  return null;
}
