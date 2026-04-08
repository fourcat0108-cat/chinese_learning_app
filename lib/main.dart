import 'package:flutter/material.dart';

void main() => runApp(const DragComponentApp());

class DragComponentApp extends StatelessWidget {
  const DragComponentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: Colors.teal, useMaterial3: true),
      home: const DragGamePage(),
    );
  }
}

class DragGamePage extends StatefulWidget {
  const DragGamePage({super.key});

  @override
  State<DragGamePage> createState() => _DragGamePageState();
}

class _DragGamePageState extends State<DragGamePage> {
  final List<Map<String, dynamic>> quizList = [
    {
      'target': '校',
      'pinyin': 'ㄒㄧㄠˋ',
      'left': '木',
      'right': '交',
      'options': ['木', '禾', '交', '父'],
    },
    {
      'target': '媽',
      'pinyin': 'ㄇㄚ',
      'left': '女',
      'right': '馬',
      'options': ['女', '彳', '馬', '鳥'],
    },
    {
      'target': '請',
      'pinyin': 'ㄑㄧㄥˇ',
      'left': '言',
      'right': '青',
      'options': ['言', '氵', '青', '爭'],
    },
  ];

  int currentIndex = 0;
  String? selectedLeft;
  String? selectedRight;
  List<String> shuffledOptions = [];

  @override
  void initState() {
    super.initState();
    _generateShuffledOptions();
  }

  void _generateShuffledOptions() {
    setState(() {
      shuffledOptions = List<String>.from(quizList[currentIndex]['options']);
      shuffledOptions.shuffle();
    });
  }

  // 【新增修改】：增加拼錯時的反饋邏輯
  void checkResult() {
    final quiz = quizList[currentIndex];

    // 當左右兩邊都放了東西，才進行檢查
    if (selectedLeft != null && selectedRight != null) {
      if (selectedLeft == quiz['left'] && selectedRight == quiz['right']) {
        _showSuccessDialog();
      } else {
        // 如果拼錯了，在螢幕下方顯示提示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '再試一次！加油！',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            backgroundColor: Colors.orangeAccent,
            duration: Duration(seconds: 1), // 顯示 1 秒就消失
          ),
        );
        // 拼錯後，自動清空格子讓學生重選
        setState(() {
          selectedLeft = null;
          selectedRight = null;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 太厲害了！'),
        content: Text('你成功組合了「${quizList[currentIndex]['target']}」字！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                currentIndex = (currentIndex + 1) % quizList.length;
                selectedLeft = null;
                selectedRight = null;
                _generateShuffledOptions();
              });
            },
            child: const Text('挑戰下一題'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quiz = quizList[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('部件拖曳拼圖'),
        backgroundColor: Colors.teal[100],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Column(
            children: [
              Text(
                quiz['target'],
                style: const TextStyle(
                  fontSize: 80,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                quiz['pinyin'],
                style: const TextStyle(
                  fontSize: 28,
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('請將正確部件拖入空格中', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTargetBox(true, selectedLeft),
              const SizedBox(width: 20),
              _buildTargetBox(false, selectedRight),
            ],
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: shuffledOptions.map((comp) {
                    return _buildDraggableComponent(comp);
                  }).toList(),
                ),
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: () => setState(() {
                    selectedLeft = null;
                    selectedRight = null;
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('手動重來'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableComponent(String data) {
    return Draggable<String>(
      data: data,
      feedback: _componentTile(data, isFeedback: true),
      childWhenDragging: Opacity(opacity: 0.3, child: _componentTile(data)),
      child: _componentTile(data),
    );
  }

  Widget _buildTargetBox(bool isLeft, String? value) {
    return DragTarget<String>(
      onAcceptWithDetails: (details) {
        setState(() {
          if (isLeft) {
            selectedLeft = details.data;
          } else {
            selectedRight = details.data;
          }
        });
        checkResult(); // 每次放下後檢查
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 110,
          height: 130,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.teal, width: 2),
            borderRadius: BorderRadius.circular(15),
            color: candidateData.isNotEmpty ? Colors.teal[100] : Colors.white,
          ),
          child: Center(
            child: Text(
              value ?? (isLeft ? '左' : '右'),
              style: TextStyle(
                fontSize: value == null ? 20 : 50,
                color: value == null ? Colors.grey : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _componentTile(String text, {bool isFeedback = false}) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          border: Border.all(color: Colors.teal.shade200),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
