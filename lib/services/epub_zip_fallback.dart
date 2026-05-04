import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'book_navigation.dart';
import 'epub_common.dart';
import 'text_import_encoding.dart';
import 'word_tokenizer.dart';

/// Если [epubx] падает на невалидном UTF-8 внутри ZIP, пробуем разобрать EPUB сами:
/// container → OPF → spine → XHTML с [decodeImportTextBytes].
Future<EpubImportPayload?> extractEpubZipFallback(Uint8List bytes) async {
  late final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    return null;
  }

  ArchiveFile? fileNamed(String want) {
    final norm = want.replaceAll(r'\', '/');
    for (final f in archive.files) {
      if (!f.isFile) continue;
      final n = f.name.replaceAll(r'\', '/');
      if (n == norm || n.endsWith('/$norm')) return f;
    }
    return null;
  }

  Uint8List? raw(String path) {
    final f = fileNamed(path);
    if (f?.content == null) return null;
    return Uint8List.fromList(f!.content as List<int>);
  }

  String? textAt(String path) {
    final r = raw(path);
    if (r == null) return null;
    return decodeImportTextBytes(r);
  }

  final containerXml = textAt('META-INF/container.xml');
  if (containerXml == null) return null;

  String? opfPath;
  try {
    final doc = XmlDocument.parse(containerXml);
    for (final el in doc.descendants.whereType<XmlElement>()) {
      if (el.localName == 'rootfile') {
        opfPath = el.getAttribute('full-path');
        if (opfPath != null && opfPath.isNotEmpty) break;
      }
    }
  } catch (_) {
    return null;
  }
  if (opfPath == null || opfPath.isEmpty) return null;

  final opfDirIdx = opfPath.lastIndexOf('/');
  final opfDir = opfDirIdx >= 0 ? opfPath.substring(0, opfDirIdx + 1) : '';

  String resolveHref(String href) {
    if (href.startsWith('/')) return href.substring(1);
    return '$opfDir$href';
  }

  final opfXml = textAt(opfPath);
  if (opfXml == null) return null;

  final XmlDocument opf;
  try {
    opf = XmlDocument.parse(opfXml);
  } catch (_) {
    return null;
  }

  XmlElement? opfRoot;
  for (final el in opf.descendants.whereType<XmlElement>()) {
    if (el.localName == 'package') {
      opfRoot = el;
      break;
    }
  }
  opfRoot ??= opf.rootElement;
  if (opfRoot.localName != 'package') return null;

  XmlElement? childNamed(XmlElement parent, String name) {
    for (final c in parent.childElements) {
      if (c.localName == name) return c;
    }
    return null;
  }

  final manifestEl = childNamed(opfRoot, 'manifest');
  final spineEl = childNamed(opfRoot, 'spine');
  if (manifestEl == null || spineEl == null) return null;

  final idToHref = <String, String>{};
  for (final item in manifestEl.childElements) {
    if (item.localName != 'item') continue;
    final id = item.getAttribute('id');
    final href = item.getAttribute('href');
    if (id != null && href != null && id.isNotEmpty && href.isNotEmpty) {
      idToHref[id] = href;
    }
  }

  final spineIds = <String>[];
  for (final item in spineEl.childElements) {
    if (item.localName != 'itemref') continue;
    final idref = item.getAttribute('idref');
    if (idref != null && idref.isNotEmpty) spineIds.add(idref);
  }

  String? metaTitle;
  final md = childNamed(opfRoot, 'metadata');
  if (md != null) {
    for (final c in md.childElements) {
      if (c.localName == 'title') {
        final t = c.innerText.trim();
        if (t.isNotEmpty) {
          metaTitle = t;
          break;
        }
      }
    }
  }

  final buf = StringBuffer();
  final anchors = <({String label, int charOffset})>[];

  for (final id in spineIds) {
    final href = idToHref[id];
    if (href == null) continue;
    final full = resolveHref(href);
    final rawHtml = raw(full);
    if (rawHtml == null) continue;
    final htmlStr = decodeImportTextBytes(rawHtml);
    final plain = epubHtmlToPlainText(htmlStr);
    if (plain.isEmpty) continue;
    anchors.add((label: _labelFromHref(href), charOffset: buf.length));
    if (buf.isNotEmpty) buf.writeln();
    buf.write(plain);
  }

  final text = buf.toString();
  if (text.trim().isEmpty) return null;

  final nav = _finalizeAnchors(text, anchors);
  return EpubImportPayload(
    plainText: text,
    metadataTitle: metaTitle,
    navigation: nav.isEmpty ? null : nav,
  );
}

String _labelFromHref(String href) {
  final parts = href.split('/');
  var name = parts.isNotEmpty ? parts.last : href;
  name = Uri.decodeFull(name);
  final dot = name.lastIndexOf('.');
  if (dot > 0) name = name.substring(0, dot);
  return name.isNotEmpty ? name : href;
}

List<BookNavEntry> _finalizeAnchors(
  String text,
  List<({String label, int charOffset})> raw,
) {
  final out = <BookNavEntry>[];
  for (final r in raw) {
    final o = r.charOffset.clamp(0, text.length);
    final w = wordIndexAtSourceOffset(text, o);
    if (out.isNotEmpty && out.last.startWordIndex == w) continue;
    out.add(BookNavEntry(label: r.label, startWordIndex: w));
  }
  return out;
}
