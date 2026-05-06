import 'package:link_your_area/constant.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum GameTheme { classic, pastel, neon, dark }

class ThemeController extends GetxController {
  var currentTheme = GameTheme.classic.obs;

  @override
  void onInit() {
    super.onInit();
    saveLoadTheme(load: true);
  }

  void setTheme(GameTheme theme) {
    currentTheme.value = theme;
    saveLoadTheme(load: false);
  }

  Future<void> saveLoadTheme({required bool load}) async {
    final prefs = await SharedPreferences.getInstance();
    if (load) {
      final index = prefs.getInt('selected_theme') ?? 0;
      currentTheme.value = GameTheme.values[index];
    } else {
      await prefs.setInt('selected_theme', currentTheme.value.index);
    }
  }

  Color get backgroundColor {
    switch (currentTheme.value) {
      case GameTheme.pastel:
        return const Color(0xFFFDFCF0);
      case GameTheme.neon:
        return const Color(0xFF0F0F1B);
      case GameTheme.dark:
        return charcoalBlack;

      default:
        return Colors.white;
    }
  }

  Color get textColor {
    switch (currentTheme.value) {
      case GameTheme.neon:
        return Colors.cyanAccent;
      case GameTheme.dark:
        return Colors.white70;
      default:
        return charcoalBlack87;
    }
  }

  List<Color> get regionColors {
    switch (currentTheme.value) {
      case GameTheme.pastel:
        return [
          const Color(0xFFFFB7B2),
          const Color(0xFFFFDAC1),
          const Color(0xFFE2F0CB),
          const Color(0xFFB5EAD7),
          const Color(0xFFC7CEEA),
          const Color(0xFFF3D1F4),
        ];
      case GameTheme.neon:
        return [
          const Color(0xFFFF00FF),
          const Color(0xFF00FFFF),
          const Color(0xFF00FF00),
          const Color(0xFFFFFF00),
          const Color(0xFFFF0000),
          const Color(0xFF0000FF),
        ];
      default:
        return [
          const Color(0xFFFF7F7F),
          const Color(0xFFFFB27A),
          const Color(0xFFF9D86D),
          const Color(0xFFA3D9A5),
          const Color(0xFFA3CFFF),
          const Color(0xFFC4A3FF),
        ];
    }
  }

  BoxDecoration cellDecoration(bool isFilled, Color color,
      {bool isHover = false}) {
    double radius = (isFilled || isHover) ? 0.0 : 4.0;
    if (currentTheme.value == GameTheme.pastel) radius = isFilled ? 1.0 : 8.0;

    switch (currentTheme.value) {
      case GameTheme.neon:
        return BoxDecoration(
          color: isFilled ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(2),
          boxShadow: isFilled
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : null,
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        );
      case GameTheme.pastel:
        return BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        );
      default:
        return BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
        );
    }
  }
}
