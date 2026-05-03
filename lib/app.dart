import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_screen.dart';
import 'theme/telegram_theme.dart';

const _kThemePrefKey = 'speedreeder_theme_mode';

class SpeedreederApp extends StatefulWidget {
  const SpeedreederApp({super.key});

  @override
  State<SpeedreederApp> createState() => _SpeedreederAppState();
}

class _SpeedreederAppState extends State<SpeedreederApp>
    with WidgetsBindingObserver {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadThemePref();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (_themeMode == ThemeMode.system) {
      setState(() {});
    }
  }

  Future<void> _loadThemePref() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemePrefKey);
    if (!mounted) return;
    setState(() {
      _themeMode = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    });
  }

  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kThemePrefKey,
      switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'app_title'.tr(),
      theme: telegramLightTheme(),
      darkTheme: telegramDarkTheme(),
      themeMode: _themeMode,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: HomeScreen(
        themeMode: _themeMode,
        onThemeChanged: _setThemeMode,
      ),
    );
  }
}
