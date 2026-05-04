import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'word_tokenizer.dart';

const _kNavPrefix = 'speedreeder_book_nav_v1_';

/// Точка навигации: заголовок (глава / страница) и индекс слова RSVP.
class BookNavEntry {
  const BookNavEntry({
    required this.label,
    required this.startWordIndex,
    this.pageNumber,
  });

  final String label;
  final int startWordIndex;

  /// Если задано, в UI показывается как «Стр. N», иначе [label].
  final int? pageNumber;

  Map<String, dynamic> toJson() => {
        'l': label,
        'w': startWordIndex,
        if (pageNumber != null) 'p': pageNumber,
      };

  factory BookNavEntry.fromJson(Map<String, dynamic> j) => BookNavEntry(
        label: j['l'] as String? ?? '',
        startWordIndex: j['w'] as int,
        pageNumber: j['p'] as int?,
      );

  /// После обрезки начала текста при импорте (substring с [cropCharOffset]).
  static List<BookNavEntry>? afterCrop(
    String fullTextBeforeCrop,
    List<BookNavEntry>? nav,
    int cropCharOffset,
  ) {
    if (nav == null || nav.isEmpty) return null;
    final cut = wordIndexAtSourceOffset(fullTextBeforeCrop, cropCharOffset);
    final out = <BookNavEntry>[];
    for (final e in nav) {
      final nw = e.startWordIndex - cut;
      if (nw < 0) continue;
      if (out.isNotEmpty && out.last.startWordIndex == nw) continue;
      out.add(BookNavEntry(
        label: e.label,
        startWordIndex: nw,
        pageNumber: e.pageNumber,
      ));
    }
    return out.isEmpty ? null : out;
  }
}

Future<List<BookNavEntry>> loadBookNavigation(String bookId) async {
  final p = await SharedPreferences.getInstance();
  final raw = p.getString('$_kNavPrefix$bookId');
  if (raw == null || raw.isEmpty) return [];
  final list = jsonDecode(raw) as List<dynamic>;
  return list
      .map((e) => BookNavEntry.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}

Future<void> saveBookNavigation(String bookId, List<BookNavEntry> entries) async {
  final p = await SharedPreferences.getInstance();
  if (entries.isEmpty) {
    await p.remove('$_kNavPrefix$bookId');
    return;
  }
  await p.setString(
    _kNavPrefix + bookId,
    jsonEncode(entries.map((e) => e.toJson()).toList()),
  );
}

Future<void> removeBookNavigation(String bookId) async {
  final p = await SharedPreferences.getInstance();
  await p.remove('$_kNavPrefix$bookId');
}
