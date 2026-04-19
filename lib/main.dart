import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart'; // ✨ 新增：檔案儲存套件
import 'package:image_picker/image_picker.dart'; // ✨ 新增：選取圖片套件
import 'package:flutter/services.dart'; // ✨ 新增：剪貼簿套件

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAVpk8Fat5nx-v1mz-Rlsa8GtQiRoDnO9g",
      authDomain: "chiness-words.firebaseapp.com",
      projectId: "chiness-words",
      storageBucket: "chiness-words.firebasestorage.app",
      messagingSenderId: "415968209787",
      appId: "1:415968209787:web:6da20ca5a7dbf076ea2bde",
      measurementId: "G-75JHKWWYYG",
    ),
  );
  
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } catch (e) {
    debugPrint("設定失敗: $e");
  }

  runApp(const DragComponentApp());
}
// ============================================================================
// ✨ 課數大管家：老師請在這裡設定每個版本、年級的總課數
// ============================================================================
int getLessonCount(String version, String grade, String semester) {
  // 統一學期格式
  String s = (semester == 'up' || semester == '上學期') ? '上' : '下';
  
  // ✨ 統一年級格式：只抓第一個字 (把 '一年級' 變 '一'，原本是 '一' 的就維持不變)
  String g = grade.substring(0, 1);

  if (version == '康軒' && g == '一' && s == '上') return 6; 
  if (version == '康軒' && g == '六' && s == '下') return 9;
  if (version == '南一' && g == '一' && s == '上') return 7; 
  if (version == '南一' && g == '六' && s == '下') return 9; 
  if (version == '翰林' && g == '一' && s == '上') return 7; 
  if (version == '翰林' && g == '六' && s == '下') return 9;
  
  return 12; // 預設值
}
// ============================================================================
class DragComponentApp extends StatelessWidget {
  const DragComponentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.teal, 
        useMaterial3: true,
        fontFamily: 'BiauKai', 
        fontFamilyFallback: const ['DFKai-SB', 'TW-Kai', 'STKaiti', 'KaiTi'], 
      ),
      home: const VersionMenuPage(),
    );
  }
}

// --- 第一層：選擇版本 ---
class VersionMenuPage extends StatelessWidget {
  const VersionMenuPage({super.key});
  final List<String> versions = const ['南一', '康軒', '翰林'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('選擇教材版本', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload, color: Colors.teal, size: 30),
            tooltip: '教師專屬建檔後台',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TeacherBackendPage()),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: versions.length,
        itemBuilder: (context, index) => Card(
          child: ListTile(
            leading: const Icon(Icons.book, color: Colors.teal),
            title: Text(versions[index], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GradeMenuPage(version: versions[index]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 第二層：選擇年級 ---
class GradeMenuPage extends StatelessWidget {
  final String version;
  const GradeMenuPage({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    final List<String> grades = ['一年級', '二年級', '三年級', '四年級', '五年級', '六年級'];
    return Scaffold(
      appBar: AppBar(
        title: Text('$version - 選擇年級', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[100],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: grades.length,
        itemBuilder: (context, index) => ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LessonMenuPage(version: version, grade: grades[index]),
            ),
          ),
          child: Text(grades[index], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// --- 第三層：選擇學期與課次 ---
class LessonMenuPage extends StatelessWidget {
  final String version;
  final String grade;
  const LessonMenuPage({super.key, required this.version, required this.grade});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$grade - 選擇課次', style: const TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: '上學期'),
              Tab(text: '下學期'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLessonList(context, '上學期'),
            _buildLessonList(context, '下學期'),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonList(BuildContext context, String semester) {
    int maxLessons = getLessonCount(version, grade, semester);

    return ListView.builder(
      itemCount: maxLessons, 
      itemBuilder: (context, index) {
        String lessonName = '第 ${index + 1} 課';
        return ListTile(
          title: Text(lessonName, style: const TextStyle(fontSize: 20)),
          subtitle: Text('$version $grade $semester'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DragGamePage(info: '$version $grade $semester $lessonName'),
            ),
          ),
        );
      },
    );
  }
}

// --- 第四層：遊戲頁面 ---
class DragGamePage extends StatefulWidget {
  final String info;
  const DragGamePage({super.key, required this.info});

  @override
  State<DragGamePage> createState() => _DragGamePageState();
}

class _DragGamePageState extends State<DragGamePage> {
  List<Map<String, dynamic>> quizList = [];
  int currentIndex = 0;
  bool isLoading = true;

  List<String?> placedParts = [];
  List<bool> showErrors = [];
  
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _fetchDataFromFirestore();
  }

  String _generateDocId(String info) {
    try {
      final parts = info.split(' ');
      String v = parts[0] == '康軒' ? 'KSH' : (parts[0] == '南一' ? 'NY' : 'HL');
      String g = parts[1].substring(0, 1);
      String s = parts[2] == '上學期' ? 'up' : 'down';
      String l = parts[4].replaceAll(RegExp(r'[^0-9]'), '');
      return "${v}_$g${s}_L$l";
    } catch (e) {
      return "default_id";
    }
  }

  void _initGameState(Map<String, dynamic> quiz) {
    int partsCount = (quiz['parts'] as List).length;
    placedParts = List.filled(partsCount, null);
    showErrors = List.filled(partsCount, false);
  }

  Future<void> _fetchDataFromFirestore() async {
    try {
      String docId = _generateDocId(widget.info);
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('lessons').doc(docId).get();

      if (doc.exists) {
        Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('words')) {
          List<Map<String, dynamic>> loadedList = List<Map<String, dynamic>>.from(data['words']);
          
          for (var q in loadedList) {
            if (q['parts'] == null) {
              q['structure'] = '左右';
              q['parts'] = [
                {"char": q['left'] ?? '', "pinyin": q['left_pinyin'] ?? ''},
                {"char": q['right'] ?? '', "pinyin": q['right_pinyin'] ?? ''}
              ];
            }
          }

          setState(() {
            quizList = loadedList;
            if (quizList.isNotEmpty) {
              _initGameState(quizList[0]);
            }
            isLoading = false;
          });
        } else {
          setState(() { isLoading = false; quizList = []; });
        }
      } else {
        setState(() { isLoading = false; quizList = []; });
      }
    } catch (e) {
      debugPrint("抓取失敗: $e");
      setState(() { isLoading = false; });
    }
  }

  void _nextQuiz() {
    if (currentIndex < quizList.length - 1) {
      setState(() {
        currentIndex++;
        _initGameState(quizList[currentIndex]); 
      });
      _pageController.jumpToPage(0); 
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("🏆 恭喜過關！", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          content: const Text("你已經完成這一課所有的生字了！太棒了！", textAlign: TextAlign.center, style: TextStyle(fontSize: 20)),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.pop(context); 
                Navigator.pop(context); 
              },
              child: const Text("回到目錄", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  Widget _buildContentWidget(String content, {double fontSize = 30, Color? textColor}) {
    if (content.startsWith('http://') || content.startsWith('https://')) {
      return Image.network(
        content,
        width: fontSize,
        height: fontSize,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.broken_image, size: fontSize, color: Colors.grey);
        },
      );
    } else {
      return Text(
        content,
        style: TextStyle(
          fontSize: fontSize,
          color: textColor ?? Colors.black,
          decoration: TextDecoration.none,
          height: 1.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (quizList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.info, style: const TextStyle(fontWeight: FontWeight.bold))),
        body: const Center(child: Text("尚無資料，請老師前往後台建檔！", style: TextStyle(fontSize: 20))),
      );
    }

    final quiz = quizList[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.info, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal[100],
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text("進度: ${currentIndex + 1} / ${quizList.length}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
          )
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStudyPage(quiz), 
          _buildQuizPage(quiz),  
        ],
      ),
    );
  }

  Widget _buildStudyPage(Map<String, dynamic> quiz) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("👀 認真記住這個字", style: TextStyle(fontSize: 22, color: Colors.grey)),
        const SizedBox(height: 20),
        _rubyText(quiz['target'] ?? '?', quiz['pinyin'], fontSize: 130),
        const SizedBox(height: 50),
        ElevatedButton(
          onPressed: () => _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            backgroundColor: Colors.teal,
          ),
          child: const Text("記好了，去挑戰！", style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildQuizPage(Map<String, dynamic> quiz) {
    List<String> options = List<String>.from(quiz['options'] ?? [])..shuffle(); 
    List<dynamic> partsInfo = quiz['parts'] ?? [];

    bool isAllCorrect = true;
    for (int i = 0; i < partsInfo.length; i++) {
      if (placedParts[i] != partsInfo[i]['char']) {
        isAllCorrect = false;
        break;
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("🧩 憑記憶拼出來", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const SizedBox(height: 40),
        
        _buildPuzzleLayout(quiz),
        
        const SizedBox(height: 60),
        Wrap(
          spacing: 15,
          children: options.map((char) => _buildDraggableItem(char)).toList(),
        ),
        const SizedBox(height: 40),
        
        if (isAllCorrect)
          Column(
            children: [
              const Text("🎉 答對了！你太厲害了！", style: TextStyle(fontSize: 28, color: Colors.green, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _nextQuiz,
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text("下一題", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
              )
            ],
          )
        else
          TextButton.icon(
            onPressed: () => _pageController.animateToPage(
              0, 
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
            icon: const Icon(Icons.remove_red_eye, color: Colors.teal, size: 28),
            label: const Text("忘記了？再看一次", style: TextStyle(fontSize: 22, color: Colors.teal, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }

  Widget _buildPuzzleLayout(Map<String, dynamic> quiz) {
    String structure = quiz['structure'] ?? '左右';
    List<dynamic> parts = quiz['parts'] ?? [];
    List<Widget> children = [];

    for (int i = 0; i < parts.length; i++) {
      children.add(_buildTargetBox(i, parts[i]));
      if (i < parts.length - 1) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(" + ", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
        ));
      }
    }

    if (structure.contains('上下')) {
      return Column(mainAxisAlignment: MainAxisAlignment.center, children: children);
    } else {
      return Row(mainAxisAlignment: MainAxisAlignment.center, children: children);
    }
  }

  Widget _buildDraggableItem(String char) {
    return Draggable<String>(
      data: char,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(8)),
          child: _buildContentWidget(char, fontSize: 40, textColor: Colors.white),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.teal),
        ),
        child: _buildContentWidget(char, fontSize: 40),
      ),
    );
  }

  Widget _buildTargetBox(int index, Map<String, dynamic> partInfo) {
    String correctChar = partInfo['char'] ?? '';
    String correctPinyin = partInfo['pinyin'] ?? '';
    
    String? current = placedParts[index];
    bool isCorrect = current == correctChar;
    bool isError = showErrors[index];

    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        String data = details.data;
        setState(() {
          placedParts[index] = data;
          showErrors[index] = false;
        });

        if (data != correctChar) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                if (placedParts[index] == data) showErrors[index] = true;
              });
            }
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 90, height: 120, 
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: isCorrect ? Colors.green : (isError ? Colors.red : Colors.grey), width: isError || isCorrect ? 3 : 2),
            color: isCorrect ? Colors.green[50] : (isError ? Colors.red[50] : Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _rubyText(
                current ?? '?',
                isCorrect ? correctPinyin : "", 
                fontSize: 45 
              ),
              if (isError) 
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text("再試試", style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _rubyText(String kanji, String? zhuyin, {double fontSize = 30}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (zhuyin != null && zhuyin.isNotEmpty)
          Text(zhuyin, style: TextStyle(fontSize: fontSize * 0.35, color: Colors.teal, height: 1.0, fontWeight: FontWeight.bold)), 
        if (zhuyin == null || zhuyin.isEmpty) 
          SizedBox(height: fontSize * 0.35),
        _buildContentWidget(kanji, fontSize: fontSize), 
      ],
    );
  }
}

// ============================================================================
// ✨ 教師專屬上傳後台
// ============================================================================
class TeacherBackendPage extends StatefulWidget {
  const TeacherBackendPage({super.key});

  @override
  State<TeacherBackendPage> createState() => _TeacherBackendPageState();
}

class _TeacherBackendPageState extends State<TeacherBackendPage> {
  String selectedVersion = '康軒';
  String selectedGrade = '一';
  String selectedSemester = 'up'; 
  int selectedLesson = 1;
  
  final TextEditingController _dataController = TextEditingController();
  bool isUploading = false;
  bool isUploadingImage = false; // ✨ 記錄圖片上傳狀態

  void _checkLessonLimit() {
    int maxLessons = getLessonCount(selectedVersion, selectedGrade, selectedSemester);
    if (selectedLesson > maxLessons) {
      selectedLesson = 1; 
    }
  }

  void _showResultDialog(String title, String message, {bool isSuccess = false, String? urlToCopy}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: TextStyle(color: isSuccess ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
        content: Text(message, style: const TextStyle(fontSize: 18)),
        actions: [
          // ✨ 如果有網址，顯示「複製網址」按鈕
          if (urlToCopy != null)
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, color: Colors.white),
              label: const Text("複製網址", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: urlToCopy));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已複製圖片網址！請貼到 Excel 裡。')));
                Navigator.pop(context);
              },
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (isSuccess && urlToCopy == null) {
                _dataController.clear(); 
              }
            },
            child: const Text("我知道了", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  // ✨ 終極升級：選取圖片並上傳到 Firebase Storage
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => isUploadingImage = true);
      try {
        final bytes = await image.readAsBytes();
        
        // 建立唯一的檔案名稱
        String fileName = 'custom_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        
        // 指向 Firebase Storage
        Reference ref = FirebaseStorage.instance.ref().child(fileName);
        
        // 上傳檔案
        UploadTask uploadTask = ref.putData(bytes);
        TaskSnapshot snapshot = await uploadTask;
        
        // 取得可以顯示的網址
        String downloadUrl = await snapshot.ref.getDownloadURL();

        if (!mounted) return;
        _showResultDialog(
          "🖼️ 圖片上傳成功！", 
          "圖片已經存入雲端，請點擊下方按鈕複製網址，然後將網址貼到您的 Excel 表格中代替文字部件！\n\n網址：\n$downloadUrl", 
          isSuccess: true,
          urlToCopy: downloadUrl
        );

      } catch (e) {
        if (!mounted) return;
        _showResultDialog(
          "圖片上傳失敗 (權限問題)", 
          "Firebase Storage 發生錯誤。這通常是因為您的 Storage 尚未開啟，或是規則不允許寫入。\n(提示：請到 Firebase Console 的 Storage -> Rules 將規則改為 allow read, write: if true;)\n\n錯誤代碼：\n$e"
        );
      } finally {
        if (mounted) setState(() => isUploadingImage = false);
      }
    }
  }

  Future<void> _uploadData() async {
    String rawText = _dataController.text.trim();
    if (rawText.isEmpty) {
      _showResultDialog("提示", "你還沒貼上任何資料喔！請把 Excel 的資料貼到大格子裡。");
      return;
    }

    setState(() => isUploading = true);

    try {
      List<String> lines = rawText.split('\n');
      List<Map<String, dynamic>> wordsToUpload = [];

      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        
        List<String> parts;
        if (line.contains('\t')) {
          parts = line.split('\t').map((e) => e.trim()).toList();
        } else {
          parts = line.split(RegExp(r',|，|、')).map((e) => e.trim()).toList();
        }

        if (parts.length >= 6) {
          String structure = parts[2];
          List<String> chars = parts[3].split('+').map((e) => e.trim()).toList();
          List<String> pinyins = parts[4].trim().isEmpty ? [] : parts[4].split('+').map((e) => e.trim()).toList();
          
          List<Map<String, String>> partList = [];
          for(int i = 0; i < chars.length; i++) {
            partList.add({
              "char": chars[i],
              "pinyin": i < pinyins.length ? pinyins[i] : "" 
            });
          }

          List<String> parsedOptions = [];
          if (parts[5].contains('http') || parts[5].contains(',') || parts[5].contains('，')) {
             parsedOptions = parts[5].split(RegExp(r',|，')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          } else {
             parsedOptions = parts[5].replaceAll(' ', '').runes.map((r) => String.fromCharCode(r)).toList();
          }

          wordsToUpload.add({
            "target": parts[0],
            "pinyin": parts[1], 
            "structure": structure,
            "parts": partList,
            "options": parsedOptions, 
          });
        } else {
          debugPrint("❌ 這一行解析失敗：$line");
        }
      }

      if (wordsToUpload.isEmpty) {
        if (!mounted) return;
        setState(() => isUploading = false);
        _showResultDialog(
          "格式錯誤", 
          "我們沒有找到符合格式的資料！\n\n請確認你貼上的資料有對齊這 6 個欄位：\n1.目標字\n2.拼音(可空)\n3.結構(獨體/左右...)\n4.部件(用+連)\n5.部件拼音(可空)\n6.拖拉選項"
        );
        return;
      }

      String vStr = selectedVersion == '康軒' ? 'KSH' : (selectedVersion == '南一' ? 'NY' : 'HL');
      String docId = "${vStr}_$selectedGrade${selectedSemester}_L$selectedLesson";

      await FirebaseFirestore.instance.collection('lessons').doc(docId).set({
        'title': '$selectedVersion $selectedGrade年級 ${selectedSemester == 'up' ? '上學期' : '下學期'} 第 $selectedLesson 課',
        'words': wordsToUpload,
      });

      if (!mounted) return;
      setState(() => isUploading = false);
      _showResultDialog(
        "🎉 上傳成功", 
        "太棒了！成功上傳 ${wordsToUpload.length} 個生字到【$selectedVersion 第$selectedLesson課】！\n\n現在你可以回首頁點進去試玩了！", 
        isSuccess: true
      );

    } catch (e) {
      if (!mounted) return;
      setState(() => isUploading = false);
      _showResultDialog(
        "上傳失敗 (權限問題)", 
        "Firebase 發生錯誤了！這通常是因為你的 Firebase 資料庫「不允許寫入」。\n\n錯誤代碼：\n$e"
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int currentMaxLessons = getLessonCount(selectedVersion, selectedGrade, selectedSemester);

    return Scaffold(
      appBar: AppBar(
        title: const Text('☁️ 教師建檔後台', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[200],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("1. 選擇要建檔的課次目標", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDropdown('版本', ['康軒', '南一', '翰林'], selectedVersion, (v) => setState(() { selectedVersion = v!; _checkLessonLimit(); })),
                        _buildDropdown('年級', ['一', '二', '三', '四', '五', '六'], selectedGrade, (v) => setState(() { selectedGrade = v!; _checkLessonLimit(); })),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDropdown('學期', ['up', 'down'], selectedSemester, (v) => setState(() { selectedSemester = v!; _checkLessonLimit(); }), displayMapper: (v) => v == 'up' ? '上學期' : '下學期'),
                        
                        _buildDropdown('課次', List.generate(currentMaxLessons, (index) => (index + 1).toString()), selectedLesson.toString(), (v) => setState(() => selectedLesson = int.parse(v!)), displayMapper: (v) => '第 $v 課'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // ✨ 在標題區塊加入上傳圖片按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("2. 貼上生字資料 (從 Excel 複製)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ElevatedButton.icon(
                  onPressed: isUploadingImage ? null : _pickAndUploadImage,
                  icon: isUploadingImage 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.image, color: Colors.white),
                  label: Text(isUploadingImage ? "上傳中..." : "🖼️ 上傳圖片取網址", style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text("⚠️ 有圖片的請貼網址，並且選項用逗號 (,) 隔開！", style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            TextField(
              controller: _dataController,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: "教學範例：(請在 Excel 打好貼上)\n\n拍\tㄆㄞ\t左右\t扌+白\tㄕㄡˇ+ㄅㄞˊ\t木禾扌白日\n向\tㄒㄧㄤˋ\t內外\thttps://圖片網址.png+口\t+ㄎㄡˇ\thttps://圖片網址.png,口,日,白",
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: isUploading ? null : _uploadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isUploading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("🚀 一鍵上傳至 Firebase", style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value, void Function(String?) onChanged, {String Function(String)? displayMapper}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(displayMapper != null ? displayMapper(e) : e, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}