import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final DatabaseService dbService;
  const QuizScreen({super.key, required this.dbService});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  int _totalRiskScore = 0; // Logic variable to track user's answers

  final List<Map<String, dynamic>> _questions = [
    {
      'question': 'Q1: When was your last severe acid reflux flare-up?',
      'options': [
        'a. Over a month ago',
        'b. Within the last 2 weeks',
        'c. I am experiencing one right now'
      ],
      'scores': [1, 3, 5] // Added actual mathematical weights to the answers
    },
    {
      'question':
          'Q2: Are you currently taking a daily prescribed maintenance medication for GERD (e.g., Omeprazole, Pantoprazole)?',
      'options': [
        'a. Yes, and I take it daily as prescribed',
        'b. Yes, but I frequently miss doses',
        'c. No, I only use over-the-counter medicine when it hurts'
      ],
      'scores': [1, 2, 4]
    },
    {
      'question':
          'Q3: In the past, how often have powdered beverages (like 3-in-1 coffee, citrus juices, or milk teas) triggered your acid reflux?',
      'options': [
        'a. 1 to 2 sachets',
        'b. 3 to 5 sachets',
        'c. More than 5 sachets'
      ],
      'scores': [1, 3, 5]
    },
  ];

  int? _selectedOptionIndex;

  void _handleNext() {
    // Add score of selected option
    _totalRiskScore +=
        _questions[_currentIndex]['scores'][_selectedOptionIndex] as int;

    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
      });
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // Pass the calculated score logically to the result screen
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => ResultScreen(
                  dbService: widget.dbService, finalScore: _totalRiskScore)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                  onPressed: () {
                    if (_currentIndex > 0) {
                      setState(() {
                        _currentIndex--;
                        _selectedOptionIndex = null;
                      });
                      _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text('Gerd-Q',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                    'Select the option that best describes your experience',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.05),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5))
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_questions[index]['question'],
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                      height: 1.4)),
                              const SizedBox(height: 20),
                              ...List.generate(
                                  _questions[index]['options'].length,
                                  (optIndex) {
                                bool isSelected =
                                    _selectedOptionIndex == optIndex;
                                return InkWell(
                                  onTap: () => setState(
                                      () => _selectedOptionIndex = optIndex),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 15),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                            isSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_unchecked,
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textGrey,
                                            size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Text(
                                                _questions[index]['options']
                                                    [optIndex],
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: isSelected
                                                        ? AppColors.primary
                                                        : AppColors.textGrey,
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.normal))),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(30.0),
                child: GradientButton(
                  text: _currentIndex == _questions.length - 1
                      ? 'Submit'
                      : 'Next',
                  onPressed: _selectedOptionIndex == null ? null : _handleNext,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
