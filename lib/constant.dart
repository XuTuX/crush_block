// constants.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get supabaseUrl =>
    (dotenv.env['SUPABASE_URL'] ?? const String.fromEnvironment('SUPABASE_URL'))
        .trim();
String get supabaseAnonKey => (dotenv.env['SUPABASE_ANON_KEY'] ??
        const String.fromEnvironment('SUPABASE_ANON_KEY'))
    .trim();
const String gameId = 'crush_block';

const Map<String, List<List<Offset>>> mpBlockShapesByType = {
  'I': [
    [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(3, 0)],
    [Offset(0, 0), Offset(0, 1), Offset(0, 2), Offset(0, 3)],
    [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(3, 0)],
    [Offset(0, 0), Offset(0, 1), Offset(0, 2), Offset(0, 3)],
  ],
  'O': [
    [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(1, 1)],
    [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(1, 1)],
    [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(1, 1)],
    [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(1, 1)],
  ],
  'T': [
    [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(1, 1)],
    [Offset(1, 0), Offset(1, 1), Offset(1, 2), Offset(0, 1)],
    [Offset(1, 0), Offset(0, 1), Offset(1, 1), Offset(2, 1)],
    [Offset(0, 0), Offset(0, 1), Offset(0, 2), Offset(1, 1)],
  ],
  'L': [
    [Offset(0, 0), Offset(0, 1), Offset(0, 2), Offset(1, 2)],
    [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(0, 1)],
    [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(1, 2)],
    [Offset(2, 0), Offset(0, 1), Offset(1, 1), Offset(2, 1)],
  ],
  'J': [
    [Offset(1, 0), Offset(1, 1), Offset(1, 2), Offset(0, 2)],
    [Offset(0, 0), Offset(0, 1), Offset(1, 1), Offset(2, 1)],
    [Offset(0, 0), Offset(1, 0), Offset(0, 1), Offset(0, 2)],
    [Offset(0, 0), Offset(1, 0), Offset(2, 0), Offset(2, 1)],
  ],
  'S': [
    [Offset(1, 0), Offset(2, 0), Offset(0, 1), Offset(1, 1)],
    [Offset(0, 0), Offset(0, 1), Offset(1, 1), Offset(1, 2)],
    [Offset(1, 0), Offset(2, 0), Offset(0, 1), Offset(1, 1)],
    [Offset(0, 0), Offset(0, 1), Offset(1, 1), Offset(1, 2)],
  ],
  'Z': [
    [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(2, 1)],
    [Offset(1, 0), Offset(1, 1), Offset(0, 1), Offset(0, 2)],
    [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(2, 1)],
    [Offset(1, 0), Offset(1, 1), Offset(0, 1), Offset(0, 2)],
  ],
};

const Color charcoalBlack = Color(0xFF1A1A1A);

const int gridRows = 9;
const int gridColumns = 9;
const int rotationUnit = 4;
