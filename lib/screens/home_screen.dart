import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../services/epub_text_extractor.dart';
import '../services/library_store.dart';
import '../services/pdf_text_extractor.dart';
import '../theme/telegram_theme.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/telegram_section_card.dart';
import 'reader_screen.dart';

final Uri _boostyDonateUri = Uri.parse('https://boosty.to/daysw/donate');
final Uri _intellectshopProjectsUri =
    Uri.parse('https://intellectshop.net/projects/');

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
  Future<List<BookOnShelf>>? _booksFuture;

  static const int _kImportPreviewMaxChars = 200000;

  @override
  void initState() {
    super.initState();
    _booksFuture = LibraryStore.instance.listBooksOnShelf();
  }

  void _reload() {
    setState(() {
      _booksFuture = LibraryStore.instance.listBooksOnShelf();
    });
  }

  String _titleFromTxtFirstLine(String text, String fallbackBaseName) {
    final firstLine = text.split('\n').first.trim();
    if (firstLine.isNotEmpty) {
      return firstLine.length > 56
          ? '${firstLine.substring(0, 56)}…'
          : firstLine;
    }
    return fallbackBaseName;
  }

  Future<void> _importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'epub', 'pdf'],
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('snack_read_failed'.tr())),
      );
      return;
    }

    final ext = p.extension(file.name).toLowerCase();
    final baseName = file.name.isNotEmpty
        ? p.basenameWithoutExtension(file.name)
        : 'Book';

    late final String text;
    late final String title;

    if (ext == '.pdf') {
      try {
        text = await extractPlainTextFromPdfBytes(
          bytes,
          sourceName: file.name.isNotEmpty ? file.name : null,
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('snack_pdf_extract_failed'.tr())),
        );
        return;
      }
      if (text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('snack_pdf_no_text'.tr())),
        );
        return;
      }
      title = baseName;
    } else if (ext == '.epub') {
      try {
        final payload = await extractEpubForSpeedreader(bytes);
        text = payload.plainText;
        final meta = payload.metadataTitle;
        if (meta != null && meta.isNotEmpty) {
          title = meta.length > 56 ? '${meta.substring(0, 56)}…' : meta;
        } else {
          title = baseName;
        }
      } on EpubExtractException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      }
    } else {
      try {
        text = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {
        text = String.fromCharCodes(bytes);
      }
      if (text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('snack_empty_file'.tr())),
        );
        return;
      }
      title = _titleFromTxtFirstLine(text, baseName);
    }

    if (!mounted) return;
    final startOffset = await showDialog<int?>(
      context: context,
      builder: (ctx) => _ImportStartDialog(fullText: text),
    );
    if (!mounted) return;
    if (startOffset == null) return;

    var finalText = text;
    final o = startOffset.clamp(0, text.length);
    finalText = text.substring(o);

    if (finalText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('snack_empty_file'.tr())),
      );
      return;
    }

    var finalTitle = title;
    if (ext == '.txt' || ext == '.pdf') {
      finalTitle = _titleFromTxtFirstLine(finalText, baseName);
    }

    await LibraryStore.instance.addBook(title: finalTitle, fullText: finalText);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('snack_book_added'.tr())),
    );
  }

  Widget _bookListTile(BookOnShelf entry, Color warm) {
    final m = entry.meta;
    final dateStr =
        '${DateTime.fromMillisecondsSinceEpoch(m.addedMs).toLocal()}';
    return ListTile(
      isThreeLine: entry.totalWords > 0,
      title: Text(m.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dateStr,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: warm),
          ),
          if (entry.totalWords > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 5,
                value:
                    ((entry.wordIndex + 1) / entry.totalWords).clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'reader_progress'.tr(namedArgs: {
                'current': '${entry.wordIndex + 1}',
                'total': '${entry.totalWords}',
                'pct': '${entry.progressPercent}',
              }),
              style:
                  Theme.of(context).textTheme.labelSmall?.copyWith(color: warm),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(m),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(bookId: m.id),
          ),
        );
        if (mounted) _reload();
      },
    );
  }

  Future<void> _confirmDelete(BookMeta book) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_confirm_title'.tr()),
        content: Text('«${book.title}»'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('delete_cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('delete_action'.tr()),
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
        title: Text('app_title'.tr()),
      ),
      drawer: Drawer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    margin: EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        'app_title'.tr(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  TelegramSectionCard(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.language_outlined),
                          title: Text('language'.tr()),
                          trailing: DropdownButton<Locale>(
                            underline: const SizedBox.shrink(),
                            value: context.locale,
                            items: [
                              DropdownMenuItem(
                                value: const Locale('ru'),
                                child: Text('lang_menu_ru'.tr()),
                              ),
                              DropdownMenuItem(
                                value: const Locale('en'),
                                child: Text('lang_menu_en'.tr()),
                              ),
                            ],
                            onChanged: (locale) {
                              if (locale != null) {
                                context.setLocale(locale);
                              }
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Icon(
                            widget.themeMode == ThemeMode.system
                                ? Icons.brightness_auto_outlined
                                : widget.themeMode == ThemeMode.dark
                                    ? Icons.dark_mode_outlined
                                    : Icons.light_mode_outlined,
                          ),
                          title: Text('theme'.tr()),
                          trailing: DropdownButton<ThemeMode>(
                            underline: const SizedBox.shrink(),
                            value: widget.themeMode,
                            items: [
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('theme_system'.tr()),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('light_theme'.tr()),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('dark_theme'.tr()),
                              ),
                            ],
                            onChanged: (m) {
                              if (m != null) {
                                widget.onThemeChanged(m);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  TelegramSectionCard(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text('about'.tr()),
                          onTap: () {
                            Navigator.pop(context);
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('about'.tr()),
                                content: SingleChildScrollView(
                                  child: Text('about_text'.tr()),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(),
                                    child: Text('ok'.tr()),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.lightbulb_outline),
                          title: Text('tips'.tr()),
                          onTap: () {
                            Navigator.pop(context);
                            showDialog<void>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('tips'.tr()),
                                content: SingleChildScrollView(
                                  child: Text('tips_text'.tr()),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(ctx).pop(),
                                    child: Text('ok'.tr()),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title: Text('feedback_menu'.tr()),
                          onTap: () {
                            Navigator.pop(context);
                            showFeedbackDialog(context);
                          },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading:
                              const Icon(Icons.volunteer_activism_outlined),
                          title: Text('donate'.tr()),
                          onTap: () async {
                            Navigator.pop(context);
                            final ok = await launchUrl(
                              _boostyDonateUri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!context.mounted || ok) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('donate_error'.tr())),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    dense: true,
                    title: Text(
                      'storage_notice'.tr(),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: TelegramSectionCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.apps_outlined),
                    title: Text('other_projects'.tr()),
                    subtitle: Text('other_projects_intellectshop'.tr()),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () async {
                      Navigator.pop(context);
                      final ok = await launchUrl(
                        _intellectshopProjectsUri,
                        mode: LaunchMode.externalApplication,
                      );
                      if (!context.mounted || ok) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('donate_error'.tr())),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<BookOnShelf>>(
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
                  'empty_library'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }
          final warm = TelegramColors.libraryWarmSecondary(
            Theme.of(context).brightness,
          );
          return ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 88),
            children: [
              TelegramSectionCard(
                child: Column(
                  children: [
                    for (var i = 0; i < books.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _bookListTile(books[i], warm),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _importBook,
        icon: const Icon(Icons.upload_file),
        label: Text('import_fab'.tr()),
      ),
    );
  }
}

class _ImportStartDialog extends StatefulWidget {
  final String fullText;

  const _ImportStartDialog({required this.fullText});

  @override
  State<_ImportStartDialog> createState() => _ImportStartDialogState();
}

class _ImportStartDialogState extends State<_ImportStartDialog> {
  final TextEditingController _previewController = TextEditingController();
  final TextEditingController _findController = TextEditingController();
  final ScrollController _previewScroll = ScrollController();

  late final String _previewText;
  late final bool _truncated;

  @override
  void dispose() {
    _previewController.dispose();
    _findController.dispose();
    _previewScroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final t = widget.fullText;
    if (t.length > _HomeScreenState._kImportPreviewMaxChars) {
      _previewText = t.substring(0, _HomeScreenState._kImportPreviewMaxChars);
      _truncated = true;
    } else {
      _previewText = t;
      _truncated = false;
    }
    _previewController.text = _previewText;
    _previewController.selection = const TextSelection.collapsed(offset: 0);
  }

  void _findNext() {
    final needle = _findController.text.trim();
    if (needle.isEmpty) return;
    final from = (_previewController.selection.end).clamp(0, _previewText.length);
    var idx = _previewText.indexOf(needle, from);
    if (idx < 0 && from > 0) {
      idx = _previewText.indexOf(needle);
    }
    if (idx < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('snack_anchor_not_found'.tr())),
      );
      return;
    }
    _previewController.selection = TextSelection(
      baseOffset: idx,
      extentOffset: (idx + needle.length).clamp(0, _previewText.length),
    );
  }

  void _submitSelection() {
    final sel = _previewController.selection;
    final start = sel.isValid ? sel.start : -1;
    if (start < 0) {
      Navigator.pop(context, 0);
      return;
    }
    Navigator.pop(context, start.clamp(0, widget.fullText.length));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('import_start_title'.tr()),
      content: SizedBox(
        width: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'import_start_help'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (_truncated) ...[
              const SizedBox(height: 8),
              Text(
                'import_start_truncated'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _findController,
                    decoration: InputDecoration(
                      hintText: 'import_start_find_hint'.tr(),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _findNext(),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonal(
                  onPressed: _findNext,
                  child: Text('import_start_find'.tr()),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: TextField(
                controller: _previewController,
                scrollController: _previewScroll,
                readOnly: true,
                maxLines: 12,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('import_start_cancel'.tr()),
        ),
        FilledButton.tonal(
          onPressed: () => Navigator.pop(context, 0),
          child: Text('import_start_from_begin'.tr()),
        ),
        FilledButton(
          onPressed: _submitSelection,
          child: Text('import_start_here'.tr()),
        ),
      ],
    );
  }
}
