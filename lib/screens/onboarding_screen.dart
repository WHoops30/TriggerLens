import 'package:flutter/material.dart';
import '../widgets/reassurance_card.dart';
import '../services/database_service.dart';
import 'calibration_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final DatabaseService dbService;

  const OnboardingScreen({Key? key, required this.dbService}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  int? _selectedGoal;
  int? _selectedFrequency;
  int? _selectedBaseline;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final double calculatedPralTarget = _selectedBaseline == 0 ? 0.0 : 15.0;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CalibrationScreen(
            dbService: widget.dbService,
            goalIndex: _selectedGoal!,
            frequencyIndex: _selectedFrequency!,
            baselineIndex: _selectedBaseline!,
            targetPral: calculatedPralTarget,
          ),
        ),
      );
    }
  }

  bool _canProceed() {
    if (_currentPage == 0) return _selectedGoal != null;
    if (_currentPage == 1) return _selectedFrequency != null;
    if (_currentPage == 2) return _selectedBaseline != null;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _currentPage == 0
                      ? const SizedBox(width: 48)
                      : IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                  TextButton(
                    onPressed: () {
                      _selectedGoal ??= 0;
                      _selectedFrequency ??= 0;
                      _selectedBaseline ??= 0;
                      _nextPage();
                    },
                    child: const Text("Skip",
                        style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildQuestionPage(
                    title: "What is your main goal with TriggerLens?",
                    children: [
                      ReassuranceCard(
                        title: "Analyze sacheted drinks",
                        reassuranceText:
                            "TriggerLens uses OCR to flag high-PRAL compounds hidden in powdered juices, teas, and instant coffee before you mix them.",
                        icon: Icons.search,
                        isSelected: _selectedGoal == 0,
                        onTap: () => setState(() => _selectedGoal = 0),
                      ),
                      ReassuranceCard(
                        title: "Prevent nocturnal reflux",
                        reassuranceText:
                            "Late-night hot chocolate or 3-in-1 coffee can severely weaken esophageal clearance. We'll help track your evening beverage cut-offs.",
                        icon: Icons.nights_stay,
                        isSelected: _selectedGoal == 1,
                        onTap: () => setState(() => _selectedGoal = 1),
                      ),
                      ReassuranceCard(
                        title: "Protect LES health",
                        reassuranceText:
                            "Lower Esophageal Sphincter pressure drops from specific lipids (like non-dairy creamers) and caffeine. We identify these in the ingredient list.",
                        icon: Icons.shield,
                        isSelected: _selectedGoal == 2,
                        onTap: () => setState(() => _selectedGoal = 2),
                      ),
                    ],
                  ),
                  _buildQuestionPage(
                    title:
                        "When do powdered beverages cause you the most reflux?",
                    children: [
                      ReassuranceCard(
                        title: "Daily morning consumption",
                        reassuranceText:
                            "Frequent exposure to high-acid morning coffee or citrus juices on an empty stomach irritates the mucosa. We'll monitor your daily intake.",
                        icon: Icons.wb_sunny,
                        isSelected: _selectedFrequency == 0,
                        onTap: () => setState(() => _selectedFrequency = 0),
                      ),
                      ReassuranceCard(
                        title: "After heavy concentrated mixes",
                        reassuranceText:
                            "Powders that are mixed with too little water increase the acidic concentration and overload the stomach lining.",
                        icon: Icons.local_drink,
                        isSelected: _selectedFrequency == 1,
                        onTap: () => setState(() => _selectedFrequency = 1),
                      ),
                      ReassuranceCard(
                        title: "Mostly when sleeping",
                        reassuranceText:
                            "Supine positioning removes gravity's protective effect after consuming warm instant drinks before bed.",
                        icon: Icons.bed,
                        isSelected: _selectedFrequency == 2,
                        onTap: () => setState(() => _selectedFrequency = 2),
                      ),
                    ],
                  ),
                  _buildQuestionPage(
                    title: "Let's calibrate your beverage PRAL baseline.",
                    children: [
                      ReassuranceCard(
                        title: "Strict low-acid protocol",
                        reassuranceText:
                            "Calculates a target negative PRAL score (<= 0) specifically for your daily beverage consumption to support esophageal recovery.",
                        icon: Icons.health_and_safety,
                        isSelected: _selectedBaseline == 0,
                        onTap: () => setState(() => _selectedBaseline = 0),
                      ),
                      ReassuranceCard(
                        title: "Balanced dietary tracking",
                        reassuranceText:
                            "Flags severe acidic outliers in sacheted drinks while monitoring your overall daily acid-alkaline balance.",
                        icon: Icons.monitor_weight,
                        isSelected: _selectedBaseline == 1,
                        onTap: () => setState(() => _selectedBaseline = 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 32.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4B72),
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _canProceed() ? _nextPage : null,
                  child: Text(
                    _currentPage == 2 ? "Commit to Baseline" : "Next",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _canProceed() ? Colors.white : Colors.grey[500],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionPage(
      {required String title, required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 40),
            ...children,
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
