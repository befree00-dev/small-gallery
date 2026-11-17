import 'package:material_ui/material_ui.dart';

import 'data/models.dart';

/// Colors from the UI mockups: a warm white-cube ground, ink text, one indigo accent.
abstract final class Palette {
  static const ground = Color(0xFFF6F5F1);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1D1C1A);
  static const muted = Color(0xFF5F5C56);
  static const line = Color(0xFFE3E0D8);
  static const accent = Color(0xFF2E4AA6);
  static const accentSoft = Color(0xFFE8ECF8);
  static const heart = Color(0xFFE58A9A);

  // Viewer (dark room)
  static const darkGround = Color(0xFF121211);
  static const darkSurface = Color(0xFF1F1E1C);
  static const darkInk = Color(0xFFF2F1ED);
  static const darkMuted = Color(0xFFA9A6A0);
  static const darkAccent = Color(0xFF8EA2E8);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Palette.accent,
    primary: Palette.accent,
    surface: Palette.ground,
    onSurface: Palette.ink,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, scaffoldBackgroundColor: Palette.ground);
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.ground,
      foregroundColor: Palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: Palette.line, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Palette.line)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD6D2C8))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Color(0xFFD6D2C8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    cardTheme: CardThemeData(
      color: Palette.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Palette.line)),
    ),
  );
}

/// The visitor-facing colors of each gallery theme.
({Color ground, Color ink, Color muted, Color frame}) galleryColors(GalleryTheme theme) => switch (theme) {
      GalleryTheme.white => (ground: Palette.ground, ink: Palette.ink, muted: Palette.muted, frame: Palette.surface),
      GalleryTheme.dark => (ground: Palette.darkGround, ink: Palette.darkInk, muted: Palette.darkMuted, frame: Palette.darkSurface),
      GalleryTheme.wood =>
        (ground: const Color(0xFFF3EDE3), ink: Palette.ink, muted: const Color(0xFF5E5448), frame: const Color(0xFF8A6A4A)),
    };

const serifTitle = TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600, letterSpacing: -0.4);
