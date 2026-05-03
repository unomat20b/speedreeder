import 'package:epubx/epubx.dart';
import 'package:html/parser.dart' as html_parser;

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
  });

  final String plainText;
  final String? metadataTitle;
}

/// Видимый текст из фрагмента XHTML/HTML (удобно для тестов).
String epubHtmlToPlainText(String? html) {
  if (html == null || html.isEmpty) return '';
  final fragment = html_parser.parseFragment(html);
  var t = fragment.text?.trim() ?? '';
  // RSVP токенизатор всё равно режет по \s+; единый пробел читабельнее.
  t = t.replaceAll(RegExp(r'\s+'), ' ');
  return t.trim();
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
    throw EpubExtractException('Не удалось разобрать EPUB: $e');
  }

  var text = _plainFromChapters(book.Chapters);
  if (text.trim().isEmpty) {
    text = _plainFromSpine(book);
  }
  if (text.trim().isEmpty) {
    text = _plainFromAllHtml(book);
  }

  if (text.trim().isEmpty) {
    throw EpubExtractException(
      'В EPUB не найдено текстового содержимого (проверьте формат книги).',
    );
  }

  final meta = book.Title?.trim();
  return EpubImportPayload(
    plainText: text,
    metadataTitle: (meta != null && meta.isNotEmpty) ? meta : null,
  );
}

String _plainFromChapters(List<EpubChapter>? chapters) {
  if (chapters == null || chapters.isEmpty) return '';
  final buf = StringBuffer();
  void walk(EpubChapter ch) {
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
  return buf.toString();
}

String _plainFromSpine(EpubBook book) {
  final pkg = book.Schema?.Package;
  final spineItems = pkg?.Spine?.Items;
  final manifestItems = pkg?.Manifest?.Items;
  final htmlMap = book.Content?.Html;
  if (spineItems == null || manifestItems == null || htmlMap == null) {
    return '';
  }

  final byId = <String, EpubManifestItem>{};
  for (final m in manifestItems) {
    final id = m.Id;
    if (id != null) byId[id] = m;
  }

  final buf = StringBuffer();
  for (final spine in spineItems) {
    final idRef = spine.IdRef;
    if (idRef == null) continue;
    final item = byId[idRef];
    final href = item?.Href;
    if (href == null) continue;
    final file = _lookupHtmlFile(htmlMap, href);
    final raw = file?.Content;
    if (raw == null || raw.isEmpty) continue;
    final plain = epubHtmlToPlainText(raw);
    if (plain.isEmpty) continue;
    if (buf.isNotEmpty) buf.writeln();
    buf.write(plain);
  }
  return buf.toString();
}

String _plainFromAllHtml(EpubBook book) {
  final htmlMap = book.Content?.Html;
  if (htmlMap == null || htmlMap.isEmpty) return '';

  final keys = htmlMap.keys.toList()..sort();
  final buf = StringBuffer();
  for (final k in keys) {
    final lower = k.toLowerCase();
    if (lower.endsWith('.ncx')) continue;
    final f = htmlMap[k];
    final raw = f?.Content;
    if (raw == null || raw.isEmpty) continue;
    final plain = epubHtmlToPlainText(raw);
    if (plain.isEmpty) continue;
    if (buf.isNotEmpty) buf.writeln();
    buf.write(plain);
  }
  return buf.toString();
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
