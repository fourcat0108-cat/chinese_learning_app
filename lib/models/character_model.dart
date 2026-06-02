// lib/models/character_model.dart

class CharacterModel {
  final String char;        // 國字本身
  final String pinyin;      // 注音
  final String structure;   // 結構
  final String components;  // 部件
  final String compPinyin;  // 部件注音
  final String distractors; // 混淆選項

  CharacterModel({
    required this.char,
    required this.pinyin,
    required this.structure,
    required this.components,
    required this.compPinyin,
    required this.distractors,
  });

  // ✨ 這裡必須確實有兩個參數：map 和 docId
  factory CharacterModel.fromMap(Map<String, dynamic> map, String docId) {
    return CharacterModel(
      char: docId, 
      pinyin: map['pinyin'] ?? '',
      structure: map['structure'] ?? '',
      components: map['components'] ?? '',
      compPinyin: map['comp_pinyin'] ?? '',
      distractors: map['options'] is List 
          ? (map['options'] as List).join(',') 
          : (map['distractors'] ?? ''),
    );
  }
}