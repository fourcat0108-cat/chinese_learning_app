import 'package:cloud_firestore/cloud_firestore.dart'; // 務必加上這一行
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 網頁版初始化必須包含 options 盒子
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
  // 加上這幾行，強制關閉網頁版的離線暫存，確保它每次都走網路
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  } catch (e) {
    debugPrint("設定失敗: $e");
  }

  runApp(const DragComponentApp());
}

class DragComponentApp extends StatelessWidget {
  const DragComponentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: Colors.teal, useMaterial3: true),
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
        title: const Text('選擇教材版本'),
        centerTitle: true,
        backgroundColor: Colors.teal[100],
        // ✨ 新增：右上角的「教師後台」入口
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload, color: Colors.teal, size: 30),
            tooltip: '教師專屬建檔後台',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TeacherBackendPage(),
                ),
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
            title: Text(versions[index], style: const TextStyle(fontSize: 24)),
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
        title: Text('$version - 選擇年級'),
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
          child: Text(grades[index], style: const TextStyle(fontSize: 20)),
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
          title: Text('$grade - 選擇課次'),
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
    return ListView.builder(
      itemCount: 20, // 改成 20 課比較充裕
      itemBuilder: (context, index) {
        String lessonName = '第 ${index + 1} 課';
        return ListTile(
          title: Text(lessonName),
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

  String? leftPlaced; // 紀錄左邊格子放了什麼字
  String? rightPlaced; // 紀錄右邊格子放了什麼字

  bool showLeftError = false;
  bool showRightError = false;

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
      String finalId = "${v}_${g}${s}_L$l";
      debugPrint("【偵錯】App 正在嘗試尋找的 ID 是: $finalId");
      return finalId;
    } catch (e) {
      return "default_id";
    }
  }

  Future<void> _fetchDataFromFirestore() async {
    try {
      String docId = _generateDocId(widget.info);
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(docId)
          .get();

      if (doc.exists) {
        setState(() {
          quizList = List<Map<String, dynamic>>.from(doc['words']);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          quizList = [];
        });
      }
    } catch (e) {
      debugPrint("抓取失敗: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  void _nextQuiz() {
    if (currentIndex < quizList.length - 1) {
      setState(() {
        currentIndex++;
        leftPlaced = null;
        rightPlaced = null;
        showLeftError = false;
        showRightError = false;
      });
      _pageController.jumpToPage(0);
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            "🏆 恭喜過關！",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 28),
          ),
          content: const Text(
            "你已經完成這一課所有的生字了！太棒了！",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "回到目錄",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (quizList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.info)),
        body: const Center(
          child: Text("尚無資料，請老師前往後台建檔！", style: TextStyle(fontSize: 20)),
        ),
      );
    }

    final quiz = quizList[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.info),
        backgroundColor: Colors.teal[100],
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(
                "進度: ${currentIndex + 1} / ${quizList.length}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [_buildStudyPage(quiz), _buildQuizPage(quiz)],
      ),
    );
  }

  Widget _buildStudyPage(Map<String, dynamic> quiz) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "👀 認真記住這個字",
          style: TextStyle(fontSize: 20, color: Colors.grey),
        ),
        const SizedBox(height: 20),
        _rubyText(quiz['target'], quiz['pinyin'], fontSize: 120),
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
          child: const Text(
            "記好了，去挑戰！",
            style: TextStyle(fontSize: 22, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizPage(Map<String, dynamic> quiz) {
    List<String> options = List<String>.from(quiz['options'])
      ..shuffle(); // 打亂選項

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("🧩 憑記憶拼出來", style: TextStyle(fontSize: 24)),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTargetBox(quiz['left'], true, quiz),
            const Text(" + ", style: TextStyle(fontSize: 30)),
            _buildTargetBox(quiz['right'], false, quiz),
          ],
        ),
        const SizedBox(height: 60),
        Wrap(
          spacing: 15,
          children: options.map((char) => _buildDraggableItem(char)).toList(),
        ),
        const SizedBox(height: 50),
        if (leftPlaced == quiz['left'] && rightPlaced == quiz['right'])
          Column(
            children: [
              const Text(
                "🎉 答對了！你太厲害了！",
                style: TextStyle(
                  fontSize: 28,
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _nextQuiz,
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                label: const Text(
                  "下一題",
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildDraggableItem(String char) {
    return Draggable<String>(
      data: char,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.teal,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            char,
            style: const TextStyle(
              fontSize: 30,
              color: Colors.white,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal),
        ),
        child: Text(char, style: const TextStyle(fontSize: 30)),
      ),
    );
  }

  // 修改：傳入整包 quiz，方便抓取裡面的注音資料
  Widget _buildTargetBox(
    String correctChar,
    bool isLeft,
    Map<String, dynamic> quiz,
  ) {
    String? current = isLeft ? leftPlaced : rightPlaced;
    bool isCorrect = current == correctChar;
    bool isError = isLeft ? showLeftError : showRightError;

    // ✨ 動態抓取資料庫裡的注音
    String correctPinyin = isLeft
        ? (quiz['left_pinyin'] ?? '')
        : (quiz['right_pinyin'] ?? '');

    return DragTarget<String>(
      onAccept: (data) {
        setState(() {
          if (isLeft) {
            leftPlaced = data;
            showLeftError = false;
          } else {
            rightPlaced = data;
            showRightError = false;
          }
        });

        if (data != correctChar) {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                if (isLeft && leftPlaced == data) showLeftError = true;
                if (!isLeft && rightPlaced == data) showRightError = true;
              });
            }
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 80,
          height: 110,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: isCorrect
                  ? Colors.green
                  : (isError ? Colors.red : Colors.grey),
              width: isError || isCorrect ? 3 : 2,
            ),
            color: isCorrect
                ? Colors.green[50]
                : (isError ? Colors.red[50] : Colors.white),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _rubyText(
                current ?? '?',
                isCorrect ? correctPinyin : "", // 答對時，顯示資料庫裡的專屬拼音
                fontSize: 40,
              ),
              if (isError)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    "再試試",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
        Text(
          zhuyin ?? '',
          style: TextStyle(
            fontSize: fontSize * 0.4,
            color: Colors.teal,
            height: 1.0,
          ),
        ),
        Text(
          kanji,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ✨ 全新開發：教師專屬上傳後台
// ============================================================================
class TeacherBackendPage extends StatefulWidget {
  const TeacherBackendPage({super.key});

  @override
  State<TeacherBackendPage> createState() => _TeacherBackendPageState();
}

class _TeacherBackendPageState extends State<TeacherBackendPage> {
  String selectedVersion = '康軒';
  String selectedGrade = '一';
  String selectedSemester = 'up'; // 對應資料庫的 up / down
  int selectedLesson = 1;

  final TextEditingController _dataController = TextEditingController();
  bool isUploading = false;

  Future<void> _uploadData() async {
    String rawText = _dataController.text.trim();
    if (rawText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("請貼上資料喔！")));
      return;
    }

    setState(() => isUploading = true);

    try {
      List<String> lines = rawText.split('\n');
      List<Map<String, dynamic>> wordsToUpload = [];

      for (String line in lines) {
        if (line.trim().isEmpty) continue;

        // 支援 Tab (Excel 預設) 或 逗號 (CSV) 分隔
        List<String> parts = line.split(RegExp(r'\t|,|，'));
        parts = parts.map((e) => e.trim()).toList();

        // 必須要有 7 個欄位才算正確的一列
        if (parts.length >= 7) {
          wordsToUpload.add({
            "target": parts[0],
            "pinyin": parts[1],
            "left": parts[2],
            "left_pinyin": parts[3],
            "right": parts[4],
            "right_pinyin": parts[5],
            "options": parts[6].split(
              '',
            ), // 把 "木禾扌白日" 拆成 ['木', '禾', '扌', '白', '日']
          });
        }
      }

      if (wordsToUpload.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("格式錯誤，解析失敗。請確認欄位數！")));
        setState(() => isUploading = false);
        return;
      }

      // 自動組合 Document ID
      String vStr = selectedVersion == '康軒'
          ? 'KSH'
          : (selectedVersion == '南一' ? 'NY' : 'HL');
      String docId =
          "${vStr}_${selectedGrade}${selectedSemester}_L$selectedLesson";

      // 寫入 Firebase
      await FirebaseFirestore.instance.collection('lessons').doc(docId).set({
        'title':
            '$selectedVersion ${selectedGrade}年級 ${selectedSemester == 'up' ? '上學期' : '下學期'} 第 $selectedLesson 課',
        'words': wordsToUpload,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("🎉 成功上傳 ${wordsToUpload.length} 個生字到 $docId！")),
      );
      _dataController.clear(); // 清空輸入框
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("上傳發生錯誤：$e")));
    }

    setState(() => isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '☁️ 教師建檔後台',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[200],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "1. 選擇要建檔的課次目標",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 10),

            // 下拉選單區塊
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDropdown(
                          '版本',
                          ['康軒', '南一', '翰林'],
                          selectedVersion,
                          (v) => setState(() => selectedVersion = v!),
                        ),
                        _buildDropdown(
                          '年級',
                          ['一', '二', '三', '四', '五', '六'],
                          selectedGrade,
                          (v) => setState(() => selectedGrade = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDropdown(
                          '學期',
                          ['up', 'down'],
                          selectedSemester,
                          (v) => setState(() => selectedSemester = v!),
                          displayMapper: (v) => v == 'up' ? '上學期' : '下學期',
                        ),
                        _buildDropdown(
                          '課次',
                          List.generate(20, (index) => (index + 1).toString()),
                          selectedLesson.toString(),
                          (v) => setState(() => selectedLesson = int.parse(v!)),
                          displayMapper: (v) => '第 $v 課',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            const Text(
              "2. 貼上生字資料 (從 Excel 複製)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "⚠️ 欄位順序：目標字 | 拼音 | 左部件 | 左拼音 | 右部件 | 右拼音 | 拖拉選項(字連在一起)",
              style: TextStyle(color: Colors.red, fontSize: 13),
            ),
            const SizedBox(height: 10),

            // 文字輸入區塊
            TextField(
              controller: _dataController,
              maxLines: 12,
              decoration: InputDecoration(
                hintText:
                    "範例：\n拍\tㄆㄞ\t扌\tㄕㄡˇ\t白\tㄅㄞˊ\t木禾扌白日\n找\tㄓㄠˇ\t扌\tㄕㄡˇ\t戈\tㄍㄜ\t木扌白日戈",
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            const SizedBox(height: 20),

            // 上傳按鈕
            ElevatedButton(
              onPressed: isUploading ? null : _uploadData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "🚀 一鍵上傳至 Firebase",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 下拉選單小工具
  Widget _buildDropdown(
    String label,
    List<String> items,
    String value,
    void Function(String?) onChanged, {
    String Function(String)? displayMapper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        DropdownButton<String>(
          value: value,
          items: items
              .map(
                (e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    displayMapper != null ? displayMapper(e) : e,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
