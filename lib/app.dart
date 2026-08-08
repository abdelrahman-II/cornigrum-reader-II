import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/settings_model.dart';
import 'providers/settings_provider.dart';
import 'screens/reader_screen.dart';

class CornigrumApp extends ConsumerWidget {
  const CornigrumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'CorNigrum Reader',
      debugShowCheckedModeBanner: false,
      themeMode: _getThemeMode(settings.theme),

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.highlightColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: settings.highlightColor,
          secondary: settings.highlightColor,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: settings.theme == AppTheme.pitchBlack
            ? Colors.black
            : const Color(0xFF09090B),
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.highlightColor,
          brightness: Brightness.dark,
        ).copyWith(
          primary: settings.highlightColor,
          secondary: settings.highlightColor,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),

      home: const ReaderScreen(),
    );
  }

  ThemeMode _getThemeMode(AppTheme theme) {
    switch (theme) {
      case AppTheme.light:
      case AppTheme.sepia:
        return ThemeMode.light;
      case AppTheme.obsidian:
      case AppTheme.pitchBlack:
        return ThemeMode.dark;
    }
  }
}