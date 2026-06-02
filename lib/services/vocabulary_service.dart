// lib/services/vocabulary_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // ✨ 引入以使用 debugPrint
import '../models/character_model.dart'; 

class VocabularyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<CharacterModel>> fetchLessonVocabulary({
    required String version,   
    required String grade,     
    required String semester,  
    required int lesson,       
  }) async {
    try {
      String mappingDocId = "${version}_${grade}_${semester}_$lesson";
      
      DocumentSnapshot mappingSnap = 
          await _db.collection('lesson_mappings').doc(mappingDocId).get();
          
      if (!mappingSnap.exists) {
        // ✨ 優化 1：改用 debugPrint，優化 2：拔掉變數的多餘大括號
        debugPrint("❌ 找不到 $mappingDocId 的課次關聯對應資料");
        return [];
      }

      List<dynamic> charList = mappingSnap.get('char_list') ?? [];
      if (charList.isEmpty) return [];

      QuerySnapshot charQuerySnap = await _db
          .collection('characters')
          .where(FieldPath.documentId, whereIn: charList)
          .get();

      // ✨ 這裡會完美對接上面的 2 個參數設定
      List<CharacterModel> vocabularyList = charQuerySnap.docs.map((doc) {
        return CharacterModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      vocabularyList.sort((a, b) => charList.indexOf(a.char).compareTo(charList.indexOf(b.char)));

      return vocabularyList;
      
    } catch (e) {
      // ✨ 優化 3：改用 debugPrint
      debugPrint("💥 撈取整合生字庫失敗: $e");
      return [];
    }
  }
}