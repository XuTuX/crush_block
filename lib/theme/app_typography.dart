import 'package:flutter/material.dart';
import 'package:link_your_area/constant.dart';

/// Unified typography system for link_your_area.
///
/// Hierarchy:
///   display  (36) → Hero title only
///   headline (28) → Screen-leading statement, medium scores
///   title    (22) → Screen / dialog titles
///   subtitle (18) → Section headers, appbar titles
///   body     (15) → Primary body text, descriptions
///   bodySmall(14) → Secondary text, emails, hints
///   label    (12) → Section labels and metadata
///   caption  (12) → Small informational text
///   tiny     (10) → Micro badges
///
/// Scores:
///   scoreDisplay (40) → Large score numbers
///   scoreMedium  (30) → Score bar numbers
///
/// Buttons:
///   button      (15) → Standard button text
///
/// Weights:
///   w700 → Titles and scores
///   w600 → Labels and buttons
///   w500 → Body and secondary text
class AppTypography {
  AppTypography._();

  static const display = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
    height: 1.15,
    color: charcoalBlack,
  );

  static const headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    height: 1.2,
    color: charcoalBlack,
  );

  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.2,
    color: charcoalBlack,
  );

  static const subtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.25,
    color: charcoalBlack,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.55,
    color: charcoalBlack,
  );

  static const bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: charcoalBlack,
  );

  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: charcoalBlack,
  );

  static const button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: charcoalBlack,
  );

  static const scoreDisplay = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 1,
    color: charcoalBlack,
  );

  static const scoreMedium = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1,
    color: charcoalBlack,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: charcoalBlack,
  );

  static const tiny = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: charcoalBlack,
  );
}
