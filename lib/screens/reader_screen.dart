import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../services/library_store.dart';
import '../services/reader_settings.dart';
import '../services/word_tokenizer.dart';

class ReaderScreen extends StatefulWidget {
  final String bookId;

  const ReaderScreen({super.key, required this.bookId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  /// Сколько слов показывать в приглушённом контексте до/после (около текущего).
  static const int _kContextWordRadius = 14;

  List<String> _words = [];
  int _index = 0;
  bool _playing = false;
  Timer? _timer;
  ReaderSettings _settings = ReaderSettings.defaults;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = LibraryStore.instance;
    final text = await store.loadText(widget.bookId);
    final progress = await store.loadProgress(widget.bookId);
    final rs = await ReaderSettingsStore.instance.load();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      setState(() {
        _loading = false;
        _words = [];
      });
      return;
    }
    final words = tokenizeForRsvp(text);
    setState(() {
      _words = words;
      _index = progress.clamp(0, words.isEmpty ? 0 : words.length - 1);
      _settings = rs;
      _loading = false;
    });
  }

  int get _msPerWord =>
      (60000 / _settings.wpm).round().clamp(50, 2000);

  Future<void> _persistProgress() async {
    await LibraryStore.instance.saveProgress(widget.bookId, _index);
  }

  void _start() {
    if (_words.isEmpty || _index >= _words.length) return;
    _timer?.cancel();
    setState(() => _playing = true);
    _timer = Timer.periodic(Duration(milliseconds: _msPerWord), (_) {
      if (!mounted) return;
      if (_index >= _words.length - 1) {
        _timer?.cancel();
        setState(() {
          _playing = false;
          _index = _words.length - 1;
        });
        _persistProgress();
        return;
      }
      setState(() => _index++);
      if (_index % 5 == 0) {
        _persistProgress();
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _playing = false);
    _persistProgress();
  }

  /// Текст до текущего слова (ближайшие слова к позиции), с «…» если есть более ранний текст.
  String _contextBeforeText() {
    if (_index <= 0) return '';
    final take = _kContextWordRadius.clamp(1, _index);
    final start = _index - take;
    final hasMore = start > 0;
    final chunk = _words.sublist(start, _index).join(' ');
    return hasMore ? '… $chunk' : chunk;
  }

  /// Текст после текущего слова, с «…» если дальше ещё есть слова.
  String _contextAfterText() {
    if (_index >= _words.length - 1) return '';
    final afterFirst = _index + 1;
    final remaining = _words.length - afterFirst;
    final take = _kContextWordRadius.clamp(1, remaining);
    final end = afterFirst + take;
    final hasMore = end < _words.length;
    final chunk = _words.sublist(afterFirst, end).join(' ');
    return hasMore ? '$chunk …' : chunk;
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        var local = _settings;
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'reader_settings_title'.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('reader_wpm'.tr(namedArgs: {'wpm': '${local.wpm}'})),
                  Slider(
                    min: 60,
                    max: 900,
                    divisions: 28,
                    value: local.wpm.toDouble(),
                    onChanged: (v) {
                      setModal(() {
                        local = ReaderSettings(
                          wpm: v.round(),
                          fontSize: local.fontSize,
                          colorIndex: local.colorIndex,
                        );
                      });
                    },
                  ),
                  Text('reader_size'
                      .tr(namedArgs: {'px': '${local.fontSize.round()}'})),
                  Slider(
                    min: 24,
                    max: 96,
                    divisions: 24,
                    value: local.fontSize,
                    onChanged: (v) {
                      setModal(() {
                        local = ReaderSettings(
                          wpm: local.wpm,
                          fontSize: v,
                          colorIndex: local.colorIndex,
                        );
                      });
                    },
                  ),
                  Text('reader_word_color'.tr()),
                  Row(
                    children: List.generate(3, (i) {
                      final selected = local.colorIndex == i;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('${i + 1}'),
                          selected: selected,
                          onSelected: (_) {
                            setModal(() {
                              local = ReaderSettings(
                                wpm: local.wpm,
                                fontSize: local.fontSize,
                                colorIndex: i,
                              );
                            });
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await ReaderSettingsStore.instance.save(local);
                      if (!mounted) return;
                      setState(() {
                        _settings = local;
                        if (_playing) {
                          _pause();
                          _start();
                        }
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text('reader_done'.tr()),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _persistProgress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _persistProgress();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('reader_title'.tr()),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _loading ? null : _openSettings,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _words.isEmpty
                ? Center(child: Text('reader_no_text'.tr()))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: LinearProgressIndicator(
                          value: _words.isEmpty
                              ? 0
                              : ((_index + 1) / _words.length).clamp(0.0, 1.0),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '${_index + 1} / ${_words.length}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final accent = ReaderSettingsStore.instance
                                .wordColor(context, _settings.colorIndex);
                            final muted = Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38);
                            final ctxSize =
                                (_settings.fontSize * 0.4).clamp(13.0, 24.0);

                            final before = _contextBeforeText();
                            final after = _contextAfterText();

                            return Center(
                              child: SingleChildScrollView(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight * 0.85,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (before.isNotEmpty) ...[
                                        Text(
                                          before,
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: ctxSize,
                                            height: 1.35,
                                            fontWeight: FontWeight.w400,
                                            color: muted,
                                          ),
                                        ),
                                        SizedBox(height: ctxSize * 0.65),
                                      ],
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _words[_index],
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: _settings.fontSize,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                      if (after.isNotEmpty) ...[
                                        SizedBox(height: ctxSize * 0.65),
                                        Text(
                                          after,
                                          textAlign: TextAlign.center,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: ctxSize,
                                            height: 1.35,
                                            fontWeight: FontWeight.w400,
                                            color: muted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: _index <= 0
                                  ? null
                                  : () {
                                      _pause();
                                      setState(() => _index--);
                                      _persistProgress();
                                    },
                              icon: const Icon(Icons.skip_previous),
                              label: Text('reader_back'.tr()),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              onPressed: _words.isEmpty
                                  ? null
                                  : (_playing ? _pause : _start),
                              icon: Icon(
                                _playing ? Icons.pause : Icons.play_arrow,
                              ),
                              label: Text(
                                _playing
                                    ? 'reader_pause'.tr()
                                    : 'reader_play'.tr(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.tonalIcon(
                              onPressed: _index >= _words.length - 1
                                  ? null
                                  : () {
                                      _pause();
                                      setState(() => _index++);
                                      _persistProgress();
                                    },
                              icon: const Icon(Icons.skip_next),
                              label: Text('reader_next'.tr()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
