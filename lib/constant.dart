// constants.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
const String gameId = 'crush_block';
const String rankedRatingGameId = '${gameId}_ranked_rating';

// 각 블록의 상대적인 셀 위치를 정의
const List<List<Offset>> blockShapes = [
  // 블록 형태 1: 기본 Tetris 블록 (예: I 블록)

  // 블록 형태 2: O 블록
  [
    Offset(0, 0),
    Offset(1, 0),
    Offset(0, 1),
    Offset(1, 1),
  ],
  // 블록 형태 3: T 블록
  [
    Offset(0, 0),
    Offset(1, 0),
    Offset(2, 0),
    Offset(1, 1),
  ],
  // 블록 형태 4: L 블록
  [
    Offset(0, 0),
    Offset(0, 1),
    Offset(0, 2),
    Offset(1, 2),
  ],
  // 블록 형태 5: J 블록
  [
    Offset(1, 0),
    Offset(1, 1),
    Offset(1, 2),
    Offset(0, 2),
  ],
  // 블록 형태 6: S 블록
  [
    Offset(1, 0),
    Offset(2, 0),
    Offset(0, 1),
    Offset(1, 1),
  ],
  // 블록 형태 7: Z 블록
  [
    Offset(0, 0),
    Offset(1, 0),
    Offset(1, 1),
    Offset(2, 1),
  ],
  [
    Offset(1, 1),
    Offset(0, 0),
    Offset(2, 2),
  ],
  [
    Offset(1, 1),
    Offset(2, 2),
  ],
  [
    Offset(0, 1),
    Offset(1, 1),
    Offset(2, 1),
  ],
  [
    Offset(1, 1),
  ],
  [
    Offset(1, 1),
    Offset(2, 1),
  ],
  [
    Offset(1, 0),
    Offset(1, 1),
    Offset(2, 1),
  ],
];

// constants.dart (계속)
const List<Color> blockColors = [
  Colors.cyan, // I 블록
  Colors.yellow, // O 블록
  Colors.purple, // T 블록
  Colors.orange, // L 블록
  Colors.blue, // J 블록
  Colors.green, // S 블록
  Colors.red, // Z 블록
];

const Color backColor = Colors.blueGrey;
const Color charcoalBlack = Color(0xFF1A1A1A);

// Multiplayer block ownership colors
const Color mpNeutralColor = Color(0xFFD1D5DB); // Neutral Gray
const Color mpMyBlockColor = Color(0xFFF7C85C); // My team
const Color mpOpBlockColor = Color(0xFFD96868); // Opponent team
const Color mpRedColor = mpOpBlockColor;
const Color mpBlueColor = mpMyBlockColor;

// Multiplayer UI palette
const Color mpBackgroundTop = Color(0xFFFFF4E6);
const Color mpBackgroundBottom = Color(0xFFE7F0FF);
const Color mpBackgroundGlowWarm = Color(0xFFFFD7A7);
const Color mpBackgroundGlowCool = Color(0xFFB5D4FF);
const Color mpPanelColor = Color(0xFFFFFCF7);
const Color mpPanelStroke = Color(0xFF2A2A2A);
const Color mpTurnMyBg = Color(0xFFFDF2ED); // Light warm orange for my turn
const Color mpTurnOpBg =
    Color(0xFFFFF9E6); // Light warm yellow for opponent's turn
const Color mpBadgeGold = Color(0xFFFFC857);
const List<Color> mpBlockPalette = [
  Color(0xFFF6A623),
  Color(0xFF7AC7FF),
  Color(0xFF85D6A4),
  Color(0xFFFF8FA3),
  Color(0xFFB39DDB),
];
final Color charcoalBlack87 = charcoalBlack.withValues(alpha: 0.87);
final Color charcoalBlack54 = charcoalBlack.withValues(alpha: 0.54);
final Color charcoalBlack45 = charcoalBlack.withValues(alpha: 0.45);
final Color charcoalBlack38 = charcoalBlack.withValues(alpha: 0.38);
final Color charcoalBlack26 = charcoalBlack.withValues(alpha: 0.26);
final Color charcoalBlack12 = charcoalBlack.withValues(alpha: 0.12);

const List<Color> regionColors = [
  Color(0xFFFF7F7F), // Slightly Deeper Red
  Color(0xFFFFB27A), // Slightly Deeper Orange
  Color.fromARGB(255, 249, 216, 109), // Slightly Deeper Yellow
  Color(0xFFA3D9A5), // Slightly Deeper Green
  Color(0xFFA3CFFF), // Slightly Deeper Blue
  Color(0xFFC4A3FF), // Slightly Deeper Purple
  Color(0xFFFFA3C2), // Slightly Deeper Pink
  Color.fromARGB(255, 124, 195, 172), // Slightly Deeper Cyan
  Color(0xFFFFD4A3), // Slightly Deeper Peach
];
// 그리드 설정
const int gridRows = 9;
const int gridColumns = 9;
const int mpMainTimeSeconds = 120;
const int mpByoyomiSeconds = 20;
const int mpByoyomiCount = 1;
const int mpTurnTimeoutSeconds = 15;

// 박스 크기
const double boxSize = 90.0;

//팀수
const int numTeams = 9;

// 블록 회전 단위
const int rotationUnit = 4;
