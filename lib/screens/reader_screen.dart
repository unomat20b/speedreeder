import 'dart:async';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/book_navigation.dart';
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
  /// Контекст вокруг RSVP-слова на паузе (шире, чем во время проигрывания).
  static const int _kContextWordRadiusPaused = 40;

  /// Во время проигрывания — компактный контекст.
  static const int _kContextWordRadiusPlaying = 14;

  static const int _kWpmAdjustStep = 10;

  /// Доля ширины экрана слева/справа для двойного нажатия (скорость) на мобильных.
  static const double _kSpeedEdgeFraction = 0.22;

  List<String> _words = [];
  int _index = 0;
  bool _playing = false;
  Timer? _timer;
  ReaderSettings _settings = ReaderSettings.defaults;
  bool _loading = true;
  final FocusNode _keyboardFocusNode = FocusNode(debugLabel: 'readerKeyboard');

  String _sourceText = '';
  List<BookNavEntry> _nav = [];
  bool _readingMode = false;
  final TextEditingController _readBodyController = TextEditingController();
  final ScrollController _readScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Клавиатурные шорткаты: нативный десктоп и широкий веб (планшет/ПК в браузере).
  bool _readerShortcutsEnabled(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.sizeOf(context).shortestSide >= 600;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  void _requestReaderKeyboardFocus() {
    if (!_readerShortcutsEnabled(context)) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyboardFocusNode.requestFocus();
      }
    });
  }

  KeyEventResult _onReaderKey(FocusNode node, KeyEvent event) {
    if (!_readerShortcutsEnabled(context)) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.space) {
      return KeyEventResult.ignored;
    }
    if (_loading || _words.isEmpty) return KeyEventResult.ignored;
    _togglePlayback();
    return KeyEventResult.handled;
  }

  void _togglePlayback() {
    if (_words.isEmpty) return;
    if (_playing) {
      _pause();
    } else {
      _start();
    }
  }

  Future<void> _load() async {
    final store = LibraryStore.instance;
    final text = await store.loadText(widget.bookId);
    final progress = await store.loadProgress(widget.bookId);
    final nav = await loadBookNavigation(widget.bookId);
    final rs = await ReaderSettingsStore.instance.load();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      setState(() {
        _loading = false;
        _words = [];
        _sourceText = '';
        _nav = [];
      });
      return;
    }
    final words = tokenizeForRsvp(text);
    setState(() {
      _words = words;
      _index = progress.clamp(0, words.isEmpty ? 0 : words.length - 1);
      _settings = rs;
      _loading = false;
      _sourceText = text;
      _nav = nav;
      _readingMode = false;
    });
    _readBodyController.text = text;
    if (words.isNotEmpty) {
      _requestReaderKeyboardFocus();
    }
  }

  int get _msPerWord =>
      (60000 / _settings.wpm).round().clamp(50, 2000);

  Future<void> _persistProgress() async {
    await LibraryStore.instance.saveProgress(widget.bookId, _index);
  }

  void _start() {
    if (_words.isEmpty || _index >= _words.length) return;
    _timer?.cancel();
    setState(() {
      _readingMode = false;
      _playing = true;
    });
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

  String _navEntryLabel(BookNavEntry e) {
    if (e.pageNumber != null) {
      return 'reader_nav_page'.tr(namedArgs: {'n': '${e.pageNumber}'});
    }
    return e.label.isNotEmpty ? e.label : '·';
  }

  void _toggleReadingLayout() {
    if (_loading || _words.isEmpty) return;
    if (_playing) _pause();
    setState(() {
      _readingMode = !_readingMode;
    });
    if (_readingMode) {
      _readBodyController.text = _sourceText;
    }
  }

  void _openNavSheet() {
    if (_nav.isEmpty) return;
    final sheetH = MediaQuery.of(context).size.height * 0.55;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: sheetH,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Text(
                    'reader_nav_title'.tr(),
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _nav.length,
                    itemBuilder: (context, i) {
                      final e = _nav[i];
                      return ListTile(
                        title: Text(
                          _navEntryLabel(e),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _index = e.startWordIndex
                                .clamp(0, _words.length - 1);
                            _readingMode = false;
                          });
                          _persistProgress();
                          _requestReaderKeyboardFocus();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _jumpToCursorInReadingView() {
    if (_sourceText.isEmpty || _words.isEmpty) return;
    final sel = _readBodyController.selection;
    if (!sel.isValid) return;
    final off = sel.start.clamp(0, _sourceText.length);
    final wi = wordIndexAtSourceOffset(_sourceText, off);
    setState(() {
      _index = wi.clamp(0, _words.length - 1);
      _readingMode = false;
    });
    _persistProgress();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('reader_jumped'.tr())),
    );
    _requestReaderKeyboardFocus();
  }

  Widget _buildReadingPane(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'reader_reading_hint'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: _readScrollController,
            thumbVisibility: true,
            child: TextField(
              controller: _readBodyController,
              scrollController: _readScrollController,
              readOnly: true,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                  ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.tonalIcon(
            onPressed: _jumpToCursorInReadingView,
            icon: const Icon(Icons.place_outlined),
            label: Text('reader_jump_here'.tr()),
          ),
        ),
      ],
    );
  }

  bool _speedGesturesEnabled(BuildContext context) =>
      !_readerShortcutsEnabled(context);

  Future<void> _adjustWpm(int delta) async {
    if (_loading || _words.isEmpty) return;
    final next =
        (_settings.wpm + delta).clamp(kReaderWpmMin, kReaderWpmMax);
    if (next == _settings.wpm) return;
    if (_speedGesturesEnabled(context)) {
      HapticFeedback.selectionClick();
    }
    final updated = ReaderSettings(
      wpm: next,
      fontSize: _settings.fontSize,
      colorIndex: _settings.colorIndex,
    );
    await ReaderSettingsStore.instance.save(updated);
    if (!mounted) return;
    setState(() => _settings = updated);
    if (_playing) {
      _timer?.cancel();
      _start();
    }
  }

  int get _progressPercent {
    if (_words.isEmpty) return 0;
    return (((_index + 1) / _words.length) * 100).round().clamp(0, 100);
  }

  int get _contextWordRadius =>
      _playing ? _kContextWordRadiusPlaying : _kContextWordRadiusPaused;

  /// Текст до текущего слова (ближайшие слова к позиции), с «…» если есть более ранний текст.
  String _contextBeforeText() {
    if (_index <= 0) return '';
    final take = _contextWordRadius.clamp(1, _index);
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
    final take = _contextWordRadius.clamp(1, remaining);
    final end = afterFirst + take;
    final hasMore = end < _words.length;
    final chunk = _words.sublist(afterFirst, end).join(' ');
    return hasMore ? '$chunk …' : chunk;
  }

  /// RSVP-слово: основной цвет + **опорная буква** (ORP) цветом акцента ошибки.
  Widget _rsvpWordRich(
    BuildContext context,
    String word,
    Color mainColor,
  ) {
    final orpColor = Theme.of(context).colorScheme.error;
    final base = TextStyle(
      fontSize: _settings.fontSize,
      fontWeight: FontWeight.w600,
      height: 1.2,
      color: mainColor,
    );
    final chars = word.characters.toList();
    if (chars.isEmpty) {
      return Text('', style: base, textAlign: TextAlign.center);
    }
    final opi = optimalRecognitionPointIndex(word).clamp(0, chars.length - 1);
    final spans = <InlineSpan>[
      if (opi > 0)
        TextSpan(text: chars.sublist(0, opi).join(), style: base),
      TextSpan(
        text: chars[opi],
        style: base.copyWith(
          color: orpColor,
          fontWeight: FontWeight.w800,
        ),
      ),
      if (opi < chars.length - 1)
        TextSpan(text: chars.sublist(opi + 1).join(), style: base),
    ];
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }

  Widget _colorPresetChoice(
    BuildContext context, {
    required int index,
    required bool selected,
    required VoidCallback onSelect,
  }) {
    final c = ReaderSettingsStore.instance.wordColor(context, index);
    final outline = Theme.of(context).colorScheme.outline.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? 0.45 : 0.35,
        );
    final sample = Localizations.localeOf(context).languageCode == 'ru'
        ? 'А'
        : 'A';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: outline, width: 1.5),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.45),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              sample,
              style: TextStyle(
                color: c,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                height: 1,
              ),
            ),
          ],
        ),
        onSelected: (_) => onSelect(),
      ),
    );
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
                    min: kReaderWpmMin.toDouble(),
                    max: kReaderWpmMax.toDouble(),
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
                  Wrap(
                    spacing: 0,
                    runSpacing: 8,
                    children: List.generate(3, (i) {
                      final selected = local.colorIndex == i;
                      return _colorPresetChoice(
                        context,
                        index: i,
                        selected: selected,
                        onSelect: () {
                          setModal(() {
                            local = ReaderSettings(
                              wpm: local.wpm,
                              fontSize: local.fontSize,
                              colorIndex: i,
                            );
                          });
                        },
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
                      _requestReaderKeyboardFocus();
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
    _keyboardFocusNode.dispose();
    _readBodyController.dispose();
    _readScrollController.dispose();
    _persistProgress();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = _readerShortcutsEnabled(context);
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _persistProgress();
      },
      child: Focus(
        focusNode: _keyboardFocusNode,
        skipTraversal: true,
        canRequestFocus: shortcuts,
        onKeyEvent: shortcuts ? _onReaderKey : null,
        child: Scaffold(
          appBar: AppBar(
            title: Text('reader_title'.tr()),
            actions: [
              if (!_loading && _words.isNotEmpty && !_playing) ...[
                if (_nav.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.toc_outlined),
                    tooltip: 'reader_nav_title'.tr(),
                    onPressed: _openNavSheet,
                  ),
                IconButton(
                  icon: Icon(
                    _readingMode ? Icons.speed_outlined : Icons.menu_book_outlined,
                  ),
                  tooltip: _readingMode
                      ? 'reader_mode_rsvp'.tr()
                      : 'reader_mode_read'.tr(),
                  onPressed: _toggleReadingLayout,
                ),
              ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          'reader_progress'.tr(namedArgs: {
                            'current': '${_index + 1}',
                            'total': '${_words.length}',
                            'pct': '$_progressPercent',
                          }),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      Expanded(
                        child: _readingMode && !_playing
                            ? _buildReadingPane(context)
                            : LayoutBuilder(
                          builder: (context, constraints) {
                            final mainWordColor = ReaderSettingsStore.instance
                                .wordColor(context, _settings.colorIndex);
                            final muted = Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.38);
                            final ctxSize =
                                (_settings.fontSize * 0.4).clamp(13.0, 24.0);

                            final showContext = !_playing;
                            final before =
                                showContext ? _contextBeforeText() : '';
                            final after = showContext ? _contextAfterText() : '';

                            final edgeW =
                                constraints.maxWidth * _kSpeedEdgeFraction;
                            final rtl = Directionality.of(context) ==
                                ui.TextDirection.rtl;
                            final slowerDelta =
                                rtl ? _kWpmAdjustStep : -_kWpmAdjustStep;
                            final fasterDelta =
                                rtl ? -_kWpmAdjustStep : _kWpmAdjustStep;
                            final showSpeedEdges = _speedGesturesEnabled(
                                  context,
                                ) &&
                                !_loading &&
                                _words.isNotEmpty &&
                                !_readingMode;

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                Center(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight:
                                            constraints.maxHeight * 0.85,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (before.isNotEmpty) ...[
                                            Text(
                                              before,
                                              textAlign: TextAlign.center,
                                              maxLines: _playing ? 3 : 8,
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
                                            child: _rsvpWordRich(
                                              context,
                                              _words[_index],
                                              mainWordColor,
                                            ),
                                          ),
                                          if (after.isNotEmpty) ...[
                                            SizedBox(height: ctxSize * 0.65),
                                            Text(
                                              after,
                                              textAlign: TextAlign.center,
                                              maxLines: _playing ? 3 : 8,
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
                                ),
                                if (showSpeedEdges) ...[
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: edgeW,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onDoubleTap: () =>
                                          _adjustWpm(slowerDelta),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: edgeW,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onDoubleTap: () =>
                                          _adjustWpm(fasterDelta),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                ],
                              ],
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
                            IconButton(
                              tooltip: 'reader_wpm_slower'.tr(),
                              onPressed: _loading || _words.isEmpty
                                  ? null
                                  : () => _adjustWpm(-_kWpmAdjustStep),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            const SizedBox(width: 4),
                            shortcuts
                                ? Tooltip(
                                    message: 'reader_shortcut_space'.tr(),
                                    waitDuration:
                                        const Duration(milliseconds: 400),
                                    child: FilledButton.icon(
                                      onPressed: _words.isEmpty
                                          ? null
                                          : _togglePlayback,
                                      icon: Icon(
                                        _playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                      label: Text(
                                        _playing
                                            ? 'reader_pause'.tr()
                                            : 'reader_play'.tr(),
                                      ),
                                    ),
                                  )
                                : FilledButton.icon(
                                    onPressed: _words.isEmpty
                                        ? null
                                        : _togglePlayback,
                                    icon: Icon(
                                      _playing
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                                    label: Text(
                                      _playing
                                          ? 'reader_pause'.tr()
                                          : 'reader_play'.tr(),
                                    ),
                                  ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'reader_wpm_faster'.tr(),
                              onPressed: _loading || _words.isEmpty
                                  ? null
                                  : () => _adjustWpm(_kWpmAdjustStep),
                              icon: const Icon(Icons.add_circle_outline),
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
      ),
    );
  }
}
