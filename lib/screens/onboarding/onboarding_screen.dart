import 'package:flutter/material.dart';
import '../../widgets/reassurance_card.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_localizations.dart';
import '../gerdq_screen.dart';
import 'clinical_assessment_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final DatabaseService dbService;

  const OnboardingScreen({super.key, required this.dbService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  String? _selectedStatus;
  String? _selectedAge;

  // FIXED: Frequency is now strictly Single-Select to prevent logic contradictions
  String? _selectedFrequency;

  // FIXED: Goals remain Multi-Select
  final List<String> _selectedGoals = [];

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finalizeOnboardingAndRoute();
    }
  }

  // FIXED: Smart Fork Routing Engine (Diagnosed vs Occasional/Preventative)
  void _finalizeOnboardingAndRoute() {
    String finalFrequency = _selectedFrequency ?? "Rarely";
    String finalGoal = _selectedGoals.join(", ");

    if (_selectedStatus == "Diagnosed GERD") {
      // Route Diagnosed users to the specific Clinical Assessment (Phase 4A)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ClinicalAssessmentScreen(
            dbService: widget.dbService,
            clinicalStatus: _selectedStatus!,
            ageGroup: _selectedAge!,
            refluxFrequency: finalFrequency,
            primaryGoal: finalGoal,
          ),
        ),
      );
    } else {
      // Route Preventative and Occasional users to the 6-Question GerdQ (Phase 4B)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GerdqScreen(
            dbService: widget.dbService,
            clinicalStatus: _selectedStatus!,
            ageGroup: _selectedAge!,
            refluxFrequency: finalFrequency,
            primaryGoal: finalGoal,
          ),
        ),
      );
    }
  }

  bool _canProceed() {
    if (_currentPage == 0) return _selectedStatus != null;
    if (_currentPage == 1) return _selectedAge != null;
    if (_currentPage == 2) return _selectedFrequency != null;
    if (_currentPage == 3) return _selectedGoals.isNotEmpty;
    return false;
  }

  void _skipOnboarding() {
    _selectedStatus ??= "Preventative";
    _selectedAge ??= "26-45";
    _selectedFrequency ??= "Rarely";
    if (_selectedGoals.isEmpty) _selectedGoals.add("Track my limit");

    _finalizeOnboardingAndRoute();
  }

  void _toggleGoal(String item) {
    setState(() {
      if (_selectedGoals.contains(item)) {
        _selectedGoals.remove(item);
      } else {
        _selectedGoals.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
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
                          icon: Icon(Icons.arrow_back, color: colors.textDark),
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                  TextButton(
                    onPressed: () => _showSkipWarning(colors, loc),
                    child: Text(loc.loc('skip'),
                        style: TextStyle(color: colors.textGrey, fontSize: 16)),
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
                    title: loc.loc('onboard_q1_title'),
                    subtitle: "Select your current status.",
                    colors: colors,
                    children: [
                      ReassuranceCard(
                        title: loc.loc('diagnosed_gerd'),
                        reassuranceText: loc.loc('diagnosed_gerd_desc'),
                        icon: Icons.medical_services_outlined,
                        isSelected: _selectedStatus == "Diagnosed GERD",
                        onTap: () =>
                            setState(() => _selectedStatus = "Diagnosed GERD"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('occasional_reflux'),
                        reassuranceText: loc.loc('occasional_reflux_desc'),
                        icon: Icons.local_fire_department_outlined,
                        isSelected: _selectedStatus == "Occasional Reflux",
                        onTap: () => setState(
                            () => _selectedStatus = "Occasional Reflux"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('preventative'),
                        reassuranceText: loc.loc('preventative_desc'),
                        icon: Icons.health_and_safety_outlined,
                        isSelected: _selectedStatus == "Preventative",
                        onTap: () =>
                            setState(() => _selectedStatus = "Preventative"),
                      ),
                    ],
                  ),
                  _buildQuestionPage(
                    title: loc.loc('onboard_q2_title'),
                    subtitle: "Select your age group.",
                    colors: colors,
                    children: [
                      ReassuranceCard(
                        title: loc.loc('under_18'),
                        reassuranceText: loc.loc('under_18_desc'),
                        icon: Icons.child_care,
                        isSelected: _selectedAge == "Under 18",
                        onTap: () => setState(() => _selectedAge = "Under 18"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('age_18_25'),
                        reassuranceText: loc.loc('age_18_25_desc'),
                        icon: Icons.person_outline,
                        isSelected: _selectedAge == "18-25",
                        onTap: () => setState(() => _selectedAge = "18-25"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('age_26_45'),
                        reassuranceText: loc.loc('age_26_45_desc'),
                        icon: Icons.work_outline,
                        isSelected: _selectedAge == "26-45",
                        onTap: () => setState(() => _selectedAge = "26-45"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('age_46_older'),
                        reassuranceText: loc.loc('age_46_older_desc'),
                        icon: Icons.elderly,
                        isSelected: _selectedAge == "46 and older",
                        onTap: () =>
                            setState(() => _selectedAge = "46 and older"),
                      ),
                    ],
                  ),
                  _buildQuestionPage(
                    title: loc.loc('onboard_q3_title'),
                    subtitle: "Select one option.",
                    colors: colors,
                    children: [
                      ReassuranceCard(
                        title: loc.loc('almost_every_day'),
                        reassuranceText: loc.loc('almost_every_day_desc'),
                        icon: Icons.calendar_today,
                        isSelected: _selectedFrequency == "Almost every day",
                        onTap: () => setState(
                            () => _selectedFrequency = "Almost every day"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('few_times_a_week'),
                        reassuranceText: loc.loc('few_times_a_week_desc'),
                        icon: Icons.view_week,
                        isSelected: _selectedFrequency == "A few times a week",
                        onTap: () => setState(
                            () => _selectedFrequency = "A few times a week"),
                      ),
                      ReassuranceCard(
                        title: 'Only after heavy meals',
                        reassuranceText:
                            'Discomfort primarily follows large or greasy dinners.',
                        icon: Icons.restaurant,
                        isSelected:
                            _selectedFrequency == "Only after heavy meals",
                        onTap: () => setState(() =>
                            _selectedFrequency = "Only after heavy meals"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('rarely'),
                        reassuranceText: loc.loc('rarely_desc'),
                        icon: Icons.event_available,
                        isSelected: _selectedFrequency == "Rarely",
                        onTap: () =>
                            setState(() => _selectedFrequency = "Rarely"),
                      ),
                    ],
                  ),
                  _buildQuestionPage(
                    title: loc.loc('onboard_q4_title'),
                    subtitle: "Select all your goals.",
                    colors: colors,
                    children: [
                      ReassuranceCard(
                        title: loc.loc('discover_hidden_triggers'),
                        reassuranceText:
                            loc.loc('discover_hidden_triggers_desc'),
                        icon: Icons.search,
                        isSelected:
                            _selectedGoals.contains("Discover hidden triggers"),
                        onTap: () => _toggleGoal("Discover hidden triggers"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('prevent_nighttime_reflux'),
                        reassuranceText:
                            loc.loc('prevent_nighttime_reflux_desc'),
                        icon: Icons.nights_stay,
                        isSelected:
                            _selectedGoals.contains("Prevent nighttime reflux"),
                        onTap: () => _toggleGoal("Prevent nighttime reflux"),
                      ),
                      ReassuranceCard(
                        title: loc.loc('track_limit'),
                        reassuranceText: loc.loc('track_limit_desc'),
                        icon: Icons.monitor_weight,
                        isSelected: _selectedGoals.contains("Track my limit"),
                        onTap: () => _toggleGoal("Track my limit"),
                      ),
                      ReassuranceCard(
                        title: 'Improve Digestion Overall',
                        reassuranceText:
                            'Focus on healthy, smooth digestion throughout the day.',
                        icon: Icons.spa,
                        isSelected:
                            _selectedGoals.contains("Improve Digestion"),
                        onTap: () => _toggleGoal("Improve Digestion"),
                      ),
                      ReassuranceCard(
                        title: 'Track Safe Drinks for Fitness',
                        reassuranceText:
                            'Identify protein powders and pre-workouts that won\'t cause heartburn.',
                        icon: Icons.fitness_center,
                        isSelected: _selectedGoals.contains("Fitness Tracking"),
                        onTap: () => _toggleGoal("Fitness Tracking"),
                      ),
                      ReassuranceCard(
                        title: 'Reduce Reliance on Antacids',
                        reassuranceText:
                            'Manage symptoms naturally through ingredient awareness.',
                        icon: Icons.medication_liquid,
                        isSelected: _selectedGoals.contains("Reduce Antacids"),
                        onTap: () => _toggleGoal("Reduce Antacids"),
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
                    backgroundColor: colors.primary,
                    disabledBackgroundColor: colors.textGrey.withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _canProceed() ? _nextPage : null,
                  child: Text(
                    loc.loc('next'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _canProceed() ? Colors.white : colors.textGrey,
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

  void _showSkipWarning(AppColors colors, AppLocalizations loc) {
    showModalBottomSheet(
        context: context,
        backgroundColor: colors.cardColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  loc.loc('are_you_sure'),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.loc('skip_warning_desc'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colors.textGrey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            side: BorderSide(color: colors.primary)),
                        onPressed: () {
                          Navigator.pop(context);
                          _skipOnboarding();
                        },
                        child: Text(loc.loc('skip_anyway'),
                            style: TextStyle(color: colors.primaryDark)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.loc('continue_quiz'),
                            style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
  }

  Widget _buildQuestionPage(
      {required String title,
      required String subtitle,
      required List<Widget> children,
      required AppColors colors}) {
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
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: colors.textDark,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textGrey,
              ),
            ),

            // FIXED: Permanent, highly visible disclaimer banner replaces the hidden tooltip
            Container(
              margin: const EdgeInsets.only(top: 20, bottom: 25),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primaryLight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: colors.primaryLight.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: colors.primaryDark, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Please be honest. TriggerLens will tailor your medical limit based on these answers.",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.primaryDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            ...children,
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
