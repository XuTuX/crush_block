import 'dart:math';
import 'package:flutter/widgets.dart';

/// Utility to detect whether the device is a tablet (iPad).
/// Uses shortest side >= 600dp as the standard heuristic.
class DeviceUtils {
  DeviceUtils._();

  /// Returns true when running on a tablet-sized device.
  static bool isTablet(BuildContext context) {
    final data = MediaQuery.of(context);
    final shortestSide = data.size.shortestSide;
    return shortestSide >= 600;
  }

  /// Returns the recommended max content width for the current device.
  static double contentMaxWidth(BuildContext context) {
    return isTablet(context) ? 720 : 600;
  }

  /// Returns the recommended shop grid column count.
  static int shopGridColumns(BuildContext context) {
    if (!isTablet(context)) return 3;
    final width = MediaQuery.of(context).size.width;
    if (width >= 1024) return 5;
    return 4;
  }

  /// Returns a clamped grid size for the game board on tablets.
  /// We cap at 480 so the board does not become absurdly large.
  static double clampedGridSize(
    double screenWidth,
    double screenHeight, {
    double phoneFraction = 0.85,
    double maxTabletGrid = 480,
    double tabletFraction = 0.55,
  }) {
    final shortestSide = min(screenWidth, screenHeight);
    final isTabletSize = shortestSide >= 600;

    if (isTabletSize) {
      double gridSize = screenWidth * tabletFraction;
      double maxGridHeight = screenHeight * 0.50;
      if (gridSize > maxGridHeight) gridSize = maxGridHeight;
      return min(gridSize, maxTabletGrid);
    }

    // Phone default
    double gridSize = screenWidth * phoneFraction;
    double maxGridHeight = screenHeight * 0.55;
    if (gridSize > maxGridHeight) gridSize = maxGridHeight;
    return gridSize;
  }
}
