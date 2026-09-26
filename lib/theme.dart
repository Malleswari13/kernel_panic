import 'package:flutter/material.dart';

import 'models.dart';

// Crop green + soil brown, readable outdoors in bright sun.
class AppTheme {
  static const _seed = Color(0xFF2F6A2E);

  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed).copyWith(
      secondary: const Color(0xFF7A5A1E),
      secondaryContainer: const Color(0xFFFFDEA6),
      onSecondaryContainer: const Color(0xFF281900),
    ),
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark).copyWith(
      secondary: const Color(0xFFEDC06F),
      secondaryContainer: const Color(0xFF5E4205),
      onSecondaryContainer: const Color(0xFFFFDEA6),
    ),
  );
}

class PriorityColors {
  static const high = Color(0xFFD32F2F);
  static const medium = Color(0xFFF29900);
  static const low = Color(0xFF388E3C);

  static Color of(ZonePriority p) => switch (p) {
        ZonePriority.high => high,
        ZonePriority.medium => medium,
        ZonePriority.low => low,
      };
}
