import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // ADDED: Network Checker
import '../services/database_service.dart';
import '../models/user_profile.dart';
import '../utils/ui_helpers.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class CoachScreen extends StatefulWidget {
  final DatabaseService dbService;
  const CoachScreen({super.key, required this.dbService});

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
      'AQ.Ab8RN6IZwhsV-lisVv1RvwWFshU3EsCb6KP-Se-JdEN-rxb7Pg';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _currentUser = FirebaseAuth.instance.currentUser;
    final profile = await widget.dbService.getUserProfile();

    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isInitializing = false;
        _messages.add(ChatMessage(
            text:
                'Hi ${_getFirstName()}! I\'m Tummy Buddy ✨ How is your tummy feeling today?',
            isUser: false));
      });
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

  Future<void> _sendMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _chatController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    // 1. OFFLINE CHECKER: Verify network connection before calling Gemini
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
              text:
                  "Oops! I need Wi-Fi to think! Please connect to the internet so I can help you. 🫧",
              isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
      return; // Stop execution here if offline
    }

    try {
      final String phase = _userProfile?.phase ?? "Maintenance";
      final String name = _getFirstName();

      final systemPrompt = """
      You are 'Tummy Buddy', the warm, empathetic, and cute AI companion for the TriggerLens app. 
      Your goal is to help $name manage their GERD and acid reflux with gentle, encouraging advice. 
      Context: $name is currently in the $phase phase of their acid reflux journey.
      
      Rules for your responses:
      1. Use a cozy, empathetic tone (e.g., "Oh no, I'm sorry your tummy is feeling upset!").
      2. Break your advice into 2 or 3 short, easy-to-read bullet points.
      3. Use gentle, comforting emojis appropriately (🍵, 🫧, 🧊, ✨, 🧸, 🩹).
      4. NEVER use harsh medical jargon or diagnose. ONLY give behavioral first-aid advice (like drinking water, sitting upright).
      5. End every response with a warm, encouraging sign-off.
      6. Keep responses strictly under 60 words so they fit nicely on a mobile screen.
      """;

      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _apiKey,
        systemInstruction: Content.system(systemPrompt),
      );

      final prompt = text;
      final content = [Content.text(prompt)];

      final response = await model
          .generateContent(content)
          .timeout(const Duration(seconds: 45));

      String cleanText = response.text?.replaceAll(RegExp(r'\*'), '') ??
          'My connection hiccuped! Can you try again? 🧸';

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: cleanText.trim(), isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
              text: 'Oops! My connection dropped. Let\'s try that again 🧊',
              isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
      }
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: Image.asset('assets/images/back_1.png',
                width: 24, color: AppColors.primaryDark),
            onPressed: () => Navigator.pop(context)),
        title: const Text('First Aid Coach',
            style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 24)),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                      ? _buildUserBubble(msg.text)
                      : _buildCoachBubble(msg.text);
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

  Widget _buildCoachBubble(String text) {
    return Padding(
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
                border: Border.all(color: AppColors.primaryLight, width: 2)),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Image.asset('assets/images/triggerlens_icon.png',
                  fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
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
              child: Text(text,
                  style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Padding(
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
                    : Image.asset('assets/images/man.png', fit: BoxFit.cover)),
          ),
        ],
      ),
    );
  }
}
