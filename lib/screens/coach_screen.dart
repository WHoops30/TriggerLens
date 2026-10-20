import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:io';
import '../services/database_service.dart';
import '../models/user_profile.dart';
import '../utils/ui_helpers.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';

class ChatMessage {
  final String text;
  final bool isUser;
  DateTime timestamp;

  ChatMessage(
      {required this.text, required this.isUser, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'],
        isUser: json['isUser'],
        timestamp: DateTime.parse(json['timestamp']),
      );
}

class CoachScreen extends StatefulWidget {
  final DatabaseService dbService;
  final String entryMode;
  final String? activeSymptom;
  final int? symptomSeverity;
  final String? scannedProduct;
  final String? dynamicContextData;

  const CoachScreen({
    super.key,
    required this.dbService,
    this.entryMode = 'general',
    this.activeSymptom,
    this.symptomSeverity,
    this.scannedProduct,
    this.dynamicContextData,
  });

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;

  User? _currentUser;
  UserProfile? _userProfile;

  static const String _apiKey =
      'AQ.Ab8RN6K5yjP8p15VJSFqHA0w16qzZwbJVes-K0uWVuWlKhfc1A';

  @override
  void initState() {
    super.initState();
    _loadUserDataAndHistory();
  }

  Future<void> _loadUserDataAndHistory() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    final profile = await widget.dbService.getUserProfile();

    if (mounted) {
      setState(() {
        _userProfile = profile;
      });
    }

    await _loadLocalHistory();
  }

  // ==========================================
  // LOCAL 14-DAY ROLLING MEMORY
  // ==========================================
  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/tummy_buddy_history.json');
  }

  Future<void> _loadLocalHistory() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        _generateOpeningGreeting();
        return;
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);

      List<ChatMessage> validMessages = [];
      final now = DateTime.now();

      // Filter out messages older than 14 days
      for (var item in jsonList) {
        final msg = ChatMessage.fromJson(item);
        if (now.difference(msg.timestamp).inDays <= 14) {
          validMessages.add(msg);
        }
      }

      if (validMessages.isEmpty) {
        _generateOpeningGreeting();
      } else {
        if (mounted) {
          setState(() {
            _messages = validMessages;
            _isInitializing = false;
          });
          _scrollToBottom();
        }
      }

      // Save the cleaned-up list back to the file (purges old messages)
      await _saveLocalHistory();
    } catch (e) {
      debugPrint("Error loading local history: $e");
      _generateOpeningGreeting();
    }
  }

  Future<void> _saveLocalHistory() async {
    try {
      final file = await _localFile;
      final jsonList = _messages.map((m) => m.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint("Error saving local history: $e");
    }
  }

  void _generateOpeningGreeting() {
    String name = _getFirstName();
    String initialMessage =
        'Hi $name! I\'m Tummy Buddy ✨ How can I help you today?';

    if (widget.entryMode == 'scanner' && widget.activeSymptom != null) {
      initialMessage =
          'Hi $name! I see you logged feeling ${widget.activeSymptom} after having ${widget.scannedProduct ?? "that product"}. I am so sorry! Do you need some gentle tips to feel better right now? 🩹';
    } else if (widget.entryMode == 'insights') {
      initialMessage =
          'Hi $name! I was just looking at your recent insights. Let\'s figure out how we can keep your daily acid load under control! 📊';
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
            text: initialMessage, isUser: false, timestamp: DateTime.now()));
        _isInitializing = false;
      });
      _saveLocalHistory();
    }
  }

  Future<void> _wipeLocalHistory() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear Chat?",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
            "This will permanently delete your conversation memory from this device."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final file = await _localFile;
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Error deleting file: $e");
      }

      setState(() {
        _messages.clear();
        _generateOpeningGreeting();
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSingleMessage(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Delete Message?",
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
        content: const Text(
            "Are you sure you want to delete this specific message?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _messages.removeAt(index);
      });
      await _saveLocalHistory();
    }
  }

  String _getFirstName() {
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.trim().isNotEmpty) {
      return _currentUser!.displayName!.split(' ').first;
    }
    if (_currentUser?.email != null && _currentUser!.email!.isNotEmpty) {
      return _currentUser!.email!.split('@').first;
    }
    return "Friend";
  }

  bool _containsEmergencyKeywords(String text) {
    List<String> emergencies = [
      'blood',
      'bleeding',
      'chest pain',
      'heart attack',
      'can\'t breathe',
      'fainting',
      'hospital',
      'emergency'
    ];
    String lowerText = text.toLowerCase();
    for (String word in emergencies) {
      if (lowerText.contains(word)) return true;
    }
    return false;
  }

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    ChatMessage newUserMsg =
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now());

    setState(() {
      _messages.add(newUserMsg);
      _chatController.clear();
      _isLoading = true;
    });

    await _saveLocalHistory();
    _scrollToBottom();

    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      _deliverBotResponse(
          "Oops! I need Wi-Fi to think! Please connect to the internet so I can help you. 🫧");
      return;
    }

    if (_containsEmergencyKeywords(text)) {
      _deliverBotResponse(
          "⚠️ This sounds like a medical emergency. I am not a doctor. Please stop using this app and seek immediate professional medical attention, go to the nearest hospital, or call emergency services right away.");
      return;
    }

    try {
      final String phase = _userProfile?.phase ?? "Maintenance";
      final String cap = _userProfile?.dynamicDailyCap.toString() ?? "15";
      final String name = _getFirstName();

      String systemPrompt = """
      You are 'Tummy Buddy', the warm, empathetic, and cute AI companion for the TriggerLens app. 
      Your goal is to help $name manage their GERD and acid reflux with gentle, encouraging behavioral advice.
      
      USER CONTEXT:
      - Phase: $phase. 
      - Daily Acid Limit: $cap.
      """;

      if (widget.entryMode == 'scanner' && widget.activeSymptom != null) {
        systemPrompt +=
            "\n- Immediate Context: $name is experiencing ${widget.activeSymptom} at severity ${widget.symptomSeverity}/10 after having ${widget.scannedProduct}. Focus on immediate behavioral first-aid.";
      } else if (widget.entryMode == 'insights' &&
          widget.dynamicContextData != null) {
        systemPrompt +=
            "\n- Insights Context: Here is $name's recent data: ${widget.dynamicContextData}. Help them understand these trends.";
      }

      systemPrompt += """
      RULES:
      1. Use a cozy, empathetic tone. Use gentle emojis (🍵, 🫧, 🧊, ✨, 🧸, 🩹).
      2. If they mention pain, prioritize immediate behavioral tips (drinking water, sitting upright, avoiding lying down).
      3. Break advice into short bullet points.
      4. NEVER diagnose, prescribe, or provide clinical medical advice. You are a behavioral coach.
      5. End every response with a warm sign-off.
      6. Keep responses under 60 words.
      """;

      final model = GenerativeModel(
        model: 'gemini-3.8-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(systemPrompt),
      );

      final recentMessages = _messages.length > 10
          ? _messages.sublist(_messages.length - 10)
          : _messages;

      List<Content> chatHistory = recentMessages.map((m) {
        return m.isUser
            ? Content.text(m.text)
            : Content.model([TextPart(m.text)]);
      }).toList();

      // Fails fast at 15 seconds so you aren't stuck waiting if the emulator network drops
      final response = await model
          .generateContent(chatHistory)
          .timeout(const Duration(seconds: 15));

      String cleanText = response.text?.replaceAll(RegExp(r'\*'), '') ??
          'My connection hiccuped! Can you try again? 🧸';
      _deliverBotResponse(cleanText.trim());
    } catch (e) {
      debugPrint("🚨 Gemini API Error: $e");
      _deliverBotResponse('DEBUG ERROR: $e');
    }
  }

  void _deliverBotResponse(String text) async {
    ChatMessage newBotMsg =
        ChatMessage(text: text, isUser: false, timestamp: DateTime.now());

    if (mounted) {
      setState(() {
        _messages.add(newBotMsg);
        _isLoading = false;
      });
      await _saveLocalHistory();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    String title = "Tummy Buddy";
    if (widget.entryMode == 'scanner') title = "First Aid Coach";
    if (widget.entryMode == 'insights') title = "Insight Analyst";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: AppColors.primaryDark),
            onPressed: () => Navigator.pop(context)),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 22)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: "Wipe Local Memory",
            onPressed: _wipeLocalHistory,
          ),
          const SizedBox(width: 10)
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              color: AppColors.primaryLight.withOpacity(0.2),
              child: const Text(
                "Chats automatically delete after 14 days. Long-press any message to delete it now.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary)),
                    );
                  }
                  final msg = _messages[index];
                  return msg.isUser
                      ? _buildUserBubble(msg.text, index)
                      : _buildCoachBubble(msg.text, index);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Container(
                decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5))
                    ]),
                child: TextField(
                  controller: _chatController,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'Tell Tummy Buddy how you feel...',
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 20),
                    suffixIcon: IconButton(
                      icon: Image.asset('assets/images/send.png',
                          color: Colors.white, width: 24),
                      onPressed: _sendMessage,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachBubble(String text, int index) {
    bool isEmergency = text.contains("⚠️");
    bool isDebugError = text.contains("DEBUG ERROR");

    return GestureDetector(
      onLongPress: () => _deleteSingleMessage(index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isEmergency || isDebugError
                          ? Colors.red
                          : AppColors.primaryLight,
                      width: 2)),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset('assets/images/triggerlens_icon.png',
                    fit: BoxFit.contain,
                    color: isEmergency || isDebugError ? Colors.red : null),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: isEmergency || isDebugError
                        ? Colors.red.shade50
                        : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                      bottomLeft: Radius.circular(5),
                    ),
                    border: isEmergency || isDebugError
                        ? Border.all(color: Colors.red.shade200)
                        : null,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Text(text,
                    style: TextStyle(
                        color: isEmergency || isDebugError
                            ? Colors.red.shade900
                            : AppColors.textDark,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(String text, int index) {
    return GestureDetector(
      onLongPress: () => _deleteSingleMessage(index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 50),
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primaryLight.withOpacity(0.8),
                    AppColors.primaryLight
                  ]),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(5),
                  ),
                ),
                child: Text(text,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 4)
                  ]),
              child: ClipOval(
                  child: _currentUser?.photoURL != null
                      ? Image.network(_currentUser!.photoURL!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                              'assets/images/man.png',
                              fit: BoxFit.cover))
                      : Image.asset('assets/images/man.png',
                          fit: BoxFit.cover)),
            ),
          ],
        ),
      ),
    );
  }
}
