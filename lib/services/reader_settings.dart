import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kWpm = 'speedreeder_wpm';
const _kFontSize = 'speedreeder_font_size';
const _kColorIndex = 'speedreeder_word_color_index';

class ReaderSettings {
  final int wpm;
  final double fontSize;
  final int colorIndex;

  const ReaderSettings({
    required this.wpm,
    required this.fontSize,
    required this.colorIndex,
  });

  static const ReaderSettings defaults = ReaderSettings(
    wpm: 300,
    fontSize: 48,
    colorIndex: 0,
  );
}

class ReaderSettingsStore {
  ReaderSettingsStore._();
  static final ReaderSettingsStore instance = ReaderSettingsStore._();

  Future<ReaderSettings> load() async {
    final p = await SharedPreferences.getInstance();
    return ReaderSettings(
      wpm: (p.getInt(_kWpm) ?? ReaderSettings.defaults.wpm).clamp(60, 900),
      fontSize:
          (p.getDouble(_kFontSize) ?? ReaderSettings.defaults.fontSize).clamp(
        24,
        96,
      ),
      colorIndex:
          (p.getInt(_kColorIndex) ?? ReaderSettings.defaults.colorIndex).clamp(
        0,
        2,
      ),
    );
  }

  Future<void> save(ReaderSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kWpm, s.wpm);
    await p.setDouble(_kFontSize, s.fontSize);
    await p.setInt(_kColorIndex, s.colorIndex);
  }

  /// Индекс 0..2: пресеты в зависимости от темы.
  Color wordColor(BuildContext context, int index) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    switch (index.clamp(0, 2)) {
      case 0:
        return dark ? Colors.white : Colors.black;
      case 1:
        return dark ? const Color(0xFFFFF8E1) : const Color(0xFF795548);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
