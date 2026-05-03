import 'dart:async';

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
                    'Настройки чтения',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text('Слов в минуту: ${local.wpm}'),
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
                  Text('Размер: ${local.fontSize.round()} px'),
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
                  const Text('Цвет слова'),
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
                    child: const Text('Готово'),
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
          title: const Text('Чтение'),
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
                ? const Center(child: Text('Нет текста'))
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
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _words[_index],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _settings.fontSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                  color: ReaderSettingsStore.instance
                                      .wordColor(context, _settings.colorIndex),
                                ),
                              ),
                            ),
                          ),
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
                              label: const Text('Назад'),
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              onPressed: _words.isEmpty
                                  ? null
                                  : (_playing ? _pause : _start),
                              icon: Icon(
                                _playing ? Icons.pause : Icons.play_arrow,
                              ),
                              label: Text(_playing ? 'Пауза' : 'Старт'),
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
                              label: const Text('Далее'),
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
