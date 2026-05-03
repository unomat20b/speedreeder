import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../services/library_store.dart';
import '../widgets/telegram_section_card.dart';
import 'reader_screen.dart';

class HomeScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final Future<void> Function(ThemeMode) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<BookMeta>>? _booksFuture;

  @override
  void initState() {
    super.initState();
    _booksFuture = LibraryStore.instance.listBooks();
  }

  void _reload() {
    setState(() {
      _booksFuture = LibraryStore.instance.listBooks();
    });
  }

  Future<void> _importTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось прочитать файл')),
      );
      return;
    }
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Файл пустой')),
      );
      return;
    }
    final baseName = file.name.isNotEmpty
        ? p.basenameWithoutExtension(file.name)
        : 'Текст';
    final firstLine = text.split('\n').first.trim();
    final title = firstLine.length > 56
        ? '${firstLine.substring(0, 56)}…'
        : (firstLine.isNotEmpty ? firstLine : baseName);
    await LibraryStore.instance.addBook(title: title, fullText: text);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Книга добавлена')),
    );
  }

  Future<void> _confirmDelete(BookMeta book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('«${book.title}»'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await LibraryStore.instance.deleteBook(book.id);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Speedreeder'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: const Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Speedreeder',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: TelegramSectionCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: Icon(
                    widget.themeMode == ThemeMode.system
                        ? Icons.brightness_auto_outlined
                        : widget.themeMode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                  ),
                  title: const Text('Тема'),
                  trailing: DropdownButton<ThemeMode>(
                    underline: const SizedBox.shrink(),
                    value: widget.themeMode,
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('Как в системе'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Светлая'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Тёмная'),
                      ),
                    ],
                    onChanged: (m) {
                      if (m != null) {
                        Navigator.pop(context);
                        widget.onThemeChanged(m);
                      }
                    },
                  ),
                ),
              ),
            ),
            const ListTile(
              dense: true,
              title: Text(
                'Тексты хранятся только на этом устройстве.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<BookMeta>>(
        future: _booksFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snapshot.data!.reversed.toList();
          if (books.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Нет книг.\nНажмите «Добавить .txt» — файл останется в памяти браузера или на устройстве.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            children: [
              TelegramSectionCard(
                child: Column(
                  children: [
                    for (var i = 0; i < books.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(books[i].title),
                        subtitle: Text(
                          '${DateTime.fromMillisecondsSinceEpoch(books[i].addedMs).toLocal()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(books[i]),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReaderScreen(bookId: books[i].id),
                            ),
                          );
                          if (mounted) _reload();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importTxt,
        icon: const Icon(Icons.upload_file),
        label: const Text('Добавить .txt'),
      ),
    );
  }
}
