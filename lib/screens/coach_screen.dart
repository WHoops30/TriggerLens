import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/database_service.dart';
import '../models/user_profile.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart';
import '../main.dart';

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

  final String? drinkCategory;
  final String? portionMeasurement;
  final double? portionCount;

  const CoachScreen({
    super.key,
    required this.dbService,
    this.entryMode = 'general',
    this.activeSymptom,
    this.symptomSeverity,
    this.scannedProduct,
    this.dynamicContextData,
    this.drinkCategory,
    this.portionMeasurement,
    this.portionCount,
  });

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isInitializing = true;

  User? _currentUser;
  UserProfile? _userProfile;

  String get _apiKey =>
      dotenv.isInitialized ? (dotenv.env['GEMINI_API_KEY'] ?? '') : '';

  @override
  void initState() {
    super.initState();
    _loadUserDataAndHistory();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
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

  Future<File> get _localFile async {
    final directory = await getApplicationDocumentsDirectory();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return File('${directory.path}/tummy_buddy_history_$uid.json');
  }

  Future<void> _loadLocalHistory() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        await _generateOpeningGreeting();
        return;
      }

      final contents = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);

      List<ChatMessage> validMessages = [];
      final now = DateTime.now();

      for (var item in jsonList) {
        final msg = ChatMessage.fromJson(item);
        if (now.difference(msg.timestamp).inDays <= 14) {
          validMessages.add(msg);
        }
      }

      if (validMessages.isEmpty) {
        await _generateOpeningGreeting();
      } else {
        if (mounted) {
          setState(() {
            _messages = validMessages;
            _isInitializing = false;
          });
          _scrollToBottom();
        }
      }

      await _saveLocalHistory();
    } catch (e) {
      debugPrint("Error loading local history: $e");
      await _generateOpeningGreeting();
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

  Future<void> _generateOpeningGreeting() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language_code') ?? 'en';

    String name = _getFirstName();
    String initialMessage = LanguageDictionary.translate(
        'greeting_general', langCode, {'name': name});

    if (widget.entryMode == 'scanner' && widget.activeSymptom != null) {
      initialMessage =
          LanguageDictionary.translate('greeting_scanner', langCode, {
        'name': name,
        'symptom': LanguageDictionary.translate(
            'symp_${widget.activeSymptom!.toLowerCase().replaceAll(' ', '_')}',
            langCode),
        'product': widget.scannedProduct ?? "that product"
      });
    } else if (widget.entryMode == 'insights') {
      initialMessage = LanguageDictionary.translate(
          'greeting_insights', langCode, {'name': name});
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
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.loc('clear_chat_q'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.errorRed)),
        content: Text(loc.loc('clear_chat_desc'),
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.loc('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.loc('delete'),
                style: const TextStyle(
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
      });

      await _generateOpeningGreeting();

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteSingleMessage(int index) async {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.loc('delete_message_q'),
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.errorRed)),
        content: Text(loc.loc('delete_message_desc'),
            style: TextStyle(color: colors.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.loc('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.errorRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.loc('delete'),
                style: const TextStyle(
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
    String rawName = "Friend";
    if (_currentUser?.displayName != null &&
        _currentUser!.displayName!.trim().isNotEmpty) {
      rawName = _currentUser!.displayName!.split(' ').first;
    } else if (_currentUser?.email != null && _currentUser!.email!.isNotEmpty) {
      rawName = _currentUser!.email!.split('@').first;
    }
    return rawName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
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
      'emergency',
      'dugo',
      'dumudugo',
      'sumasakit ang dibdib',
      'atake sa puso',
      'nahihirapang huminga',
      'hinimatay',
      'ospital'
    ];
    String lowerText = text.toLowerCase();
    for (String word in emergencies) {
      if (lowerText.contains(word)) return true;
    }
    return false;
  }

  List<String> _getDynamicQuickReplies(AppLocalizations loc) {
    bool isTagalog = loc.languageProvider.currentLanguage == 'tl';

    if (_messages.isEmpty) {
      return [
        isTagalog ? 'Sumasakit ang tiyan ko' : 'My stomach hurts',
        isTagalog ? 'Ano ang pwede kong inumin?' : 'What is safe to drink?',
        isTagalog ? 'May heartburn ako' : 'I have heartburn',
      ];
    }

    final lastMsg = _messages.last.text.toLowerCase();
    if (lastMsg.contains('scale') ||
        lastMsg.contains('rate') ||
        lastMsg.contains('1 hanggang 10') ||
        lastMsg.contains('severity')) {
      return ['1', '3', '5', '8', '10'];
    } else if (lastMsg.contains('yes or no') ||
        lastMsg.contains('oo o hindi')) {
      return [
        isTagalog ? 'Oo' : 'Yes',
        isTagalog ? 'Hindi' : 'No',
      ];
    }

    return [
      isTagalog ? 'Sumasakit ang tiyan ko' : 'My stomach hurts',
      isTagalog ? 'Ano ang pwede kong inumin?' : 'What is safe to drink?',
      isTagalog ? 'May heartburn ako' : 'I have heartburn',
    ];
  }

  Future<void> _sendMessage([String? quickReplyText]) async {
    final loc = AppLocalizations.of(context);
    final text = quickReplyText ?? _chatController.text.trim();
    if (text.isEmpty) return;

    if (_apiKey.isEmpty) {
      _deliverBotResponse(
          "⚠️ ERROR: Gemini API Key is missing.\n\n1. Ensure you have a '.env' file in your project root with your API key.\n\n2. Open your pubspec.yaml file and add the .env file to your assets like this:\n\nflutter:\n  assets:\n    - .env");
      return;
    }

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
      _deliverBotResponse(loc.loc('error_no_internet'));
      return;
    }

    if (_containsEmergencyKeywords(text)) {
      _deliverBotResponse(loc.loc('error_medical_emergency'));
      return;
    }

    try {
      final String phase = _userProfile?.phase ?? "Maintenance";
      final String cap = _userProfile?.dynamicDailyCap.toString() ?? "15";
      final String name = _getFirstName();
      final String clinicalStatus =
          _userProfile?.clinicalStatus ?? "Preventative";
      final String ageGroup = _userProfile?.ageGroup ?? "Unknown";
      final String goal = _userProfile?.primaryGoal ?? "Track limit";

      final String aiLanguage =
          loc.languageProvider.currentLanguage == 'tl' ? 'Tagalog' : 'English';

      final allItems = await widget.dbService.getPantryItems();
      final todayItems = allItems
          .where((i) => i.isConsumed && i.dateScanned.day == DateTime.now().day)
          .toList();
      String recentDrinksContext = todayItems.isEmpty
          ? "No drinks consumed today."
          : "Drinks consumed today: ${todayItems.map((i) => i.name).join(", ")}.";

      String systemPrompt = """
      You are 'Tummy Buddy', the warm, empathetic, and cute AI companion for the TriggerLens app. 
      Your goal is to help $name manage their stomach health with gentle, encouraging behavioral advice.
      
      STRICT OPERATIONAL BOUNDARIES:
      - Limit your assistance STRICTLY to commercial powdered drinks, acid reflux, digestion, and TriggerLens metrics.
      - If the user asks about unrelated topics (coding, general knowledge, other diseases), politely refuse and guide them back to stomach health.
      - If the user reports a pain severity of 8, 9, or 10, strongly recommend they consult a medical professional immediately.
      
      USER MEDICAL CONTEXT:
      - Clinical Status: $clinicalStatus
      - Age Group: $ageGroup
      - Primary Goal: $goal
      - Phase: $phase
      - Daily Acid Limit: $cap points
      - Active Consumption Data: $recentDrinksContext
      
      FIRST AID MAPPING:
      - Globus Sensation: Suggest warm water sips and diaphragmatic breathing.
      - Acid Regurgitation: Suggest strict upright posture and head elevation.
      - Dyspepsia: Suggest loosening waistbands and light upright pacing.
      - Heartburn / Burning Pain: Suggest lukewarm water or sugar-free gum.
      - Excessive Burping: Suggest avoiding carbonation and sipping slowly.
      - Nausea: Suggest smelling peppermint oil or rubbing alcohol pads; sip cold water.
      
      TRIGGER ANALOGIES:
      - "Stomach Door Openers": Loosen throat muscle, allowing acid to splash up.
      - "Stomach Stingers": Irritate sensitive stomach lining like citrus on a cut.
      - "Traffic Jams": Slow digestion that builds upward pressure.
      - "Gas Bubbles": Trapped air pushing acid upward.
      """;

      if (widget.entryMode == 'scanner' && widget.activeSymptom != null) {
        String physicalVolumeText = "";
        if (widget.portionCount != null &&
            widget.portionMeasurement != null &&
            widget.drinkCategory != null) {
          physicalVolumeText =
              "${widget.portionCount} ${widget.portionMeasurement} of a ${widget.drinkCategory}";
        } else {
          physicalVolumeText = "their drink";
        }

        systemPrompt +=
            "\n- Immediate Context: $name is experiencing ${widget.activeSymptom} at severity ${widget.symptomSeverity}/10 after having $physicalVolumeText (${widget.scannedProduct}). Focus on immediate behavioral first-aid taking this exact physical volume into account.";
      } else if (widget.entryMode == 'insights' &&
          widget.dynamicContextData != null) {
        systemPrompt +=
            "\n- Insights Context: Here is $name's recent data: ${widget.dynamicContextData}. Help them understand these trends.";
      }

      systemPrompt += """
      RULES:
      1. Use a cozy, empathetic tone with gentle emojis (🍵, 🫧, 🧊, ✨, 🧸, 🩹).
      2. Keep responses concise and strictly under 60 words.
      3. Explain triggers using the friendly Trigger Analogies.
      4. NEVER prescribe medication or offer clinical diagnoses.
      5. End every response with a supportive sign-off.
      6. STRICT RULE: You must respond to the user exclusively in $aiLanguage. Maintain your cute, empathetic tone perfectly translated in $aiLanguage.
      """;

      final model = GenerativeModel(
        model: 'gemini-3.5-flash-lite',
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

      GenerateContentResponse? response;
      int attempts = 0;
      const int maxAttempts = 3;

      while (attempts < maxAttempts) {
        try {
          attempts++;
          response = await model
              .generateContent(chatHistory)
              .timeout(const Duration(seconds: 15));
          break;
        } catch (error) {
          debugPrint("Gemini Attempt $attempts failed: $error");
          if (attempts >= maxAttempts) rethrow;
          await Future.delayed(Duration(seconds: attempts));
        }
      }

      String cleanText = response?.text?.replaceAll(RegExp(r'\*'), '') ??
          loc.loc('error_connection_hiccup');

      _deliverBotResponse(cleanText.trim());
    } catch (e) {
      debugPrint("🚨 Final Gemini Error after retries: $e");
      _deliverBotResponse(loc.loc('error_server_unreachable'));
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
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    if (_isInitializing) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    String title = loc.loc('tummy_buddy');
    if (widget.entryMode == 'scanner') title = loc.loc('tummy_buddy');
    if (widget.entryMode == 'insights') title = loc.loc('insight_analyst');

    // FIXED: Dynamic Keyboard Hugging logic
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back_1.png',
              width: 24, color: colors.primaryDark),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => MainLayoutScreen(
                    dbService: widget.dbService,
                    initialIndex: 0,
                  ),
                ),
                (route) => false,
              );
            }
          },
        ),
        title: Text(title,
            style: TextStyle(
                color: colors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 22)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: loc.loc('clear_chat_q'),
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
              color: colors.primaryLight.withOpacity(0.2),
              child: Text(
                loc.loc('chat_auto_delete_notice'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: colors.primaryDark),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildTypingIndicator(colors, loc);
                  }
                  final msg = _messages[index];
                  return msg.isUser
                      ? _buildUserBubble(msg.text, index, colors)
                      : _buildCoachBubble(msg.text, index, colors);
                },
              ),
            ),
            if (!_isLoading)
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: _getDynamicQuickReplies(loc)
                      .map((reply) => GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (reply == '1' ||
                                  reply == '3' ||
                                  reply == '5' ||
                                  reply == '8' ||
                                  reply == '10' ||
                                  reply.toLowerCase() == 'yes' ||
                                  reply.toLowerCase() == 'no' ||
                                  reply.toLowerCase() == 'oo' ||
                                  reply.toLowerCase() == 'hindi') {
                                _sendMessage(reply);
                              } else {
                                setState(() {
                                  _chatController.text = reply;
                                  _chatController.selection =
                                      TextSelection.fromPosition(
                                          TextPosition(offset: reply.length));
                                });
                                FocusScope.of(context)
                                    .requestFocus(_chatFocusNode);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                  color: colors.cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: colors.primaryLight),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2))
                                  ]),
                              child: Center(
                                  child: Text(reply,
                                      style: TextStyle(
                                          color: colors.primaryDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13))),
                            ),
                          ))
                      .toList(),
                ),
              ),
            // FIXED: Dynamic Animated Padding to hug the keyboard and clear the Scanner FAB
            AnimatedPadding(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                  left: 20, right: 20, bottom: isKeyboardOpen ? 20.0 : 95.0),
              child: Container(
                decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                          color: colors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5))
                    ]),
                child: TextField(
                  controller: _chatController,
                  focusNode: _chatFocusNode,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: loc.loc('chat_hint'),
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 25, vertical: 20),
                    suffixIcon: IconButton(
                      icon: Image.asset('assets/images/send.png',
                          color: Colors.white, width: 24),
                      onPressed: _isLoading ? null : () => _sendMessage(),
                    ),
                  ),
                  onSubmitted: (_) => _isLoading ? null : _sendMessage(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(AppColors colors, AppLocalizations loc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
                color: colors.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.primaryLight, width: 2)),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset('assets/images/triggerlens_icon.png',
                  fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                  color: colors.cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                    bottomLeft: Radius.circular(5),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.loc('tummy_buddy_typing'),
                      style: TextStyle(
                          color: colors.textGrey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.primaryLight),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildCoachBubble(String text, int index, AppColors colors) {
    bool isEmergency = text.contains("⚠️");
    bool isDebugError = text.contains("DEBUG ERROR") ||
        text.contains("trouble reaching the server") ||
        text.contains("nahihirapan") ||
        text.contains("ERROR:");

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
                  color: colors.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isEmergency || isDebugError
                          ? Colors.red
                          : colors.primaryLight,
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
                        ? (colors.isDark
                            ? Colors.red.shade900.withOpacity(0.3)
                            : Colors.red.shade50)
                        : colors.cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                      bottomLeft: Radius.circular(5),
                    ),
                    border: isEmergency || isDebugError
                        ? Border.all(
                            color: colors.isDark
                                ? Colors.red.shade900
                                : Colors.red.shade200)
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
                            ? (colors.isDark
                                ? Colors.red.shade200
                                : Colors.red.shade900)
                            : colors.textDark,
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

  Widget _buildUserBubble(String text, int index, AppColors colors) {
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
                  color: colors.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(5),
                  ),
                ),
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.white,
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
                  color: colors.primaryLight.withOpacity(0.3),
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
