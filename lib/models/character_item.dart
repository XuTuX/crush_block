import 'package:flutter/material.dart';

enum CharacterRarity {
  common,
  rare,
  epic,
  legendary,
}

class CharacterItem {
  final String id;
  final String name;
  final CharacterRarity rarity;
  final int price;
  final Color themeColor;
  final String portraitAsset;
  final String tokenAsset;

  const CharacterItem({
    required this.id,
    required this.name,
    required this.rarity,
    required this.price,
    required this.themeColor,
    required this.portraitAsset,
    required this.tokenAsset,
  });

  String get rarityLabel {
    switch (rarity) {
      case CharacterRarity.common:
        return '일반';
      case CharacterRarity.rare:
        return '레어';
      case CharacterRarity.epic:
        return '에픽';
      case CharacterRarity.legendary:
        return '전설';
    }
  }
}
