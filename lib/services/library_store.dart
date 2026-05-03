import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _kIndexKey = 'speedreeder_books_index_v1';
const _kTextPrefix = 'speedreeder_book_text_';
const _kProgressPrefix = 'speedreeder_book_progress_';

class BookMeta {
  final String id;
  final String title;
  final int addedMs;

  const BookMeta({
    required this.id,
    required this.title,
    required this.addedMs,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'addedMs': addedMs,
      };

  static BookMeta fromJson(Map<String, dynamic> j) => BookMeta(
        id: j['id'] as String,
        title: j['title'] as String,
        addedMs: j['addedMs'] as int,
      );
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
  }) async {
    final p = await SharedPreferences.getInstance();
    const uuid = Uuid();
    final id = uuid.v4();
    final meta = BookMeta(
      id: id,
      title: title,
      addedMs: DateTime.now().millisecondsSinceEpoch,
    );
    final books = await listBooks();
    books.add(meta);
    await p.setString(
      _kIndexKey,
      jsonEncode(books.map((b) => b.toJson()).toList()),
    );
    await p.setString('$_kTextPrefix$id', fullText);
    await p.setInt('$_kProgressPrefix$id', 0);
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
  }
}
