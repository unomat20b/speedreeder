import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'book_navigation.dart';
import 'word_tokenizer.dart';

const _kIndexKey = 'speedreeder_books_index_v1';
const _kTextPrefix = 'speedreeder_book_text_';
const _kProgressPrefix = 'speedreeder_book_progress_';

class BookMeta {
  final String id;
  final String title;
  final int addedMs;
  /// Число слов после `tokenizeForRsvp`; null у старых записей до первого открытия списка.
  final int? wordCount;

  const BookMeta({
    required this.id,
    required this.title,
    required this.addedMs,
    this.wordCount,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'addedMs': addedMs,
        if (wordCount != null) 'wordCount': wordCount,
      };

  static BookMeta fromJson(Map<String, dynamic> j) => BookMeta(
        id: j['id'] as String,
        title: j['title'] as String,
        addedMs: j['addedMs'] as int,
        wordCount: j['wordCount'] as int?,
      );
}

/// Элемент списка библиотеки: метаданные + прогресс чтения.
class BookOnShelf {
  final BookMeta meta;
  final int wordIndex;
  final int totalWords;

  const BookOnShelf({
    required this.meta,
    required this.wordIndex,
    required this.totalWords,
  });

  int get progressPercent {
    if (totalWords <= 0) return 0;
    return (((wordIndex + 1) / totalWords) * 100).round().clamp(0, 100);
  }
}

class LibraryStore {
  LibraryStore._();
  static final LibraryStore instance = LibraryStore._();

  Future<List<BookMeta>> listBooks() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kIndexKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => BookMeta.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Список книг с подсчётом слов и сохранённым прогрессом (для UI библиотеки).
  /// Подставляет `wordCount` в индекс, если его не было (старые импорты).
  Future<List<BookOnShelf>> listBooksOnShelf() async {
    final p = await SharedPreferences.getInstance();
    final books = await listBooks();
    final updated = <BookMeta>[];
    var indexDirty = false;
    final out = <BookOnShelf>[];

    for (final b in books) {
      var meta = b;
      var wc = b.wordCount;
      if (wc == null) {
        final t = p.getString('$_kTextPrefix${b.id}');
        wc = (t == null || t.isEmpty) ? 0 : tokenizeForRsvp(t).length;
        meta = BookMeta(
          id: b.id,
          title: b.title,
          addedMs: b.addedMs,
          wordCount: wc,
        );
        indexDirty = true;
      }
      updated.add(meta);

      final rawIdx = p.getInt('$_kProgressPrefix${b.id}') ?? 0;
      final maxIdx = wc > 0 ? wc - 1 : 0;
      final idx = wc > 0 ? rawIdx.clamp(0, maxIdx) : 0;

      out.add(BookOnShelf(
        meta: meta,
        wordIndex: idx,
        totalWords: wc,
      ));
    }

    if (indexDirty) {
      await p.setString(
        _kIndexKey,
        jsonEncode(updated.map((e) => e.toJson()).toList()),
      );
    }

    return out;
  }

  Future<String?> loadText(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('$_kTextPrefix$id');
  }

  Future<int> loadProgress(String id) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt('$_kProgressPrefix$id') ?? 0;
  }

  Future<void> saveProgress(String id, int wordIndex) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('$_kProgressPrefix$id', wordIndex);
  }

  Future<BookMeta> addBook({
    required String title,
    required String fullText,
    List<BookNavEntry>? navigation,
  }) async {
    final p = await SharedPreferences.getInstance();
    const uuid = Uuid();
    final id = uuid.v4();
    final wc = tokenizeForRsvp(fullText).length;
    final meta = BookMeta(
      id: id,
      title: title,
      addedMs: DateTime.now().millisecondsSinceEpoch,
      wordCount: wc,
    );
    final books = await listBooks();
    books.add(meta);
    await p.setString(
      _kIndexKey,
      jsonEncode(books.map((b) => b.toJson()).toList()),
    );
    await p.setString('$_kTextPrefix$id', fullText);
    await p.setInt('$_kProgressPrefix$id', 0);
    if (navigation != null) {
      await saveBookNavigation(id, navigation);
    }
    return meta;
  }

  Future<void> deleteBook(String id) async {
    final p = await SharedPreferences.getInstance();
    final books = await listBooks();
    books.removeWhere((b) => b.id == id);
    await p.setString(
      _kIndexKey,
      jsonEncode(books.map((b) => b.toJson()).toList()),
    );
    await p.remove('$_kTextPrefix$id');
    await p.remove('$_kProgressPrefix$id');
    await removeBookNavigation(id);
  }
}
