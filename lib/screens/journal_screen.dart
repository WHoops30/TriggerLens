import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/daily_log.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart'; // NEW: Localization Engine

class JournalScreen extends StatefulWidget {
  final DatabaseService dbService;
  const JournalScreen({super.key, required this.dbService});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  // Uses a Set to ensure we don't get duplicate symptoms if they tap wildly
  // NOTE: This intentionally stores the ENGLISH string for database consistency
  final Set<String> _selectedSymptoms = {};
  double _severity = 0;
  bool _isSaving = false;

  // The structured grid data mapped to localization keys
  final Map<String, List<Map<String, String>>> _symptomCategories = {
    'category_digestion': [
      {'label': 'Bloating', 'icon': '🎈', 'key': 'symp_bloating'},
      {'label': 'Nausea', 'icon': '🤢', 'key': 'symp_nausea'},
      {'label': 'Burping', 'icon': '🫧', 'key': 'symp_burping'},
    ],
    'category_pain_discomfort': [
      {'label': 'Heartburn', 'icon': '🔥', 'key': 'symp_heartburn'},
      {'label': 'Cramps', 'icon': '⚡', 'key': 'symp_cramps'},
      {'label': 'Chest Pain', 'icon': '🫀', 'key': 'symp_chest_pain'},
    ],
    'category_throat_mouth': [
      {'label': 'Acidic Taste', 'icon': '🍋', 'key': 'symp_acidic_taste'},
      {'label': 'Sore Throat', 'icon': '🧣', 'key': 'symp_sore_throat'},
      {'label': 'Dry Cough', 'icon': '😮‍💨', 'key': 'symp_dry_cough'},
    ],
  };

  void _toggleSymptom(String symptomLabel) {
    setState(() {
      if (_selectedSymptoms.contains(symptomLabel)) {
        _selectedSymptoms.remove(symptomLabel);
      } else {
        _selectedSymptoms.add(symptomLabel);
      }
    });
  }

  Future<void> _saveDailyLog(AppColors colors, AppLocalizations loc) async {
    setState(() => _isSaving = true);

    // Normalize the date to midnight so it acts as a unique ID for the entire day
    final now = DateTime.now();
    final normalizedDate = DateTime(now.year, now.month, now.day);

    final newLog = DailyLog()
      ..date = normalizedDate
      ..symptoms = _selectedSymptoms.toList()
      ..severity = _severity;

    await widget.dbService.saveDailyLog(newLog);

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.loc('daily_symptoms_logged')),
          backgroundColor: colors.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      );

      // Reset after saving
      setState(() {
        _selectedSymptoms.clear();
        _severity = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    // DateFormat automatically handles the locale string output if set,
    // but here we keep it standard for simplicity.
    final String todayDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.loc('daily_checkin'),
            style: TextStyle(
                color: colors.primaryDark,
                fontWeight: FontWeight.w900,
                fontSize: 24)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(left: 25, right: 25, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(todayDate,
                      style: TextStyle(
                          color: colors.textGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(loc.loc('how_tummy_feeling'),
                      style: TextStyle(
                          color: colors.primaryDark,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.2)),
                  const SizedBox(height: 30),

                  // Generate the Grid dynamically from our Map
                  ..._symptomCategories.entries.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 25.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.loc(category.key),
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: colors.textDark)),
                          const SizedBox(height: 15),
                          Wrap(
                            spacing: 12,
                            runSpacing: 15,
                            children: category.value.map((symptom) {
                              final isSelected =
                                  _selectedSymptoms.contains(symptom['label']);
                              return GestureDetector(
                                onTap: () => _toggleSymptom(symptom['label']!),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width:
                                      (MediaQuery.of(context).size.width - 74) /
                                          3, // 3 columns
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 15),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : Colors.grey.shade200,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                                color: colors.primary
                                                    .withOpacity(0.3),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5))
                                          ]
                                        : [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.02),
                                                blurRadius: 5)
                                          ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(symptom['icon']!,
                                          style: const TextStyle(fontSize: 28)),
                                      const SizedBox(height: 8),
                                      Text(
                                        loc.loc(symptom[
                                            'key']!), // Translate the UI display
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected
                                                ? Colors.white
                                                : colors.textGrey),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 10),

                  // Severity Slider
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5))
                        ]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(loc.loc('overall_discomfort'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: colors.textDark)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                  color: colors.primaryLight.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15)),
                              child: Text('$_severity / 10',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                      color: colors.primaryDark)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: colors.primary,
                            inactiveTrackColor: Colors.grey.shade200,
                            thumbColor: colors.primaryDark,
                            trackHeight: 8.0,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12.0),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24.0),
                          ),
                          child: Slider(
                            value: _severity,
                            min: 0,
                            max: 10,
                            divisions: 10,
                            onChanged: (val) => setState(() => _severity = val),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(loc.loc('none'),
                                  style: TextStyle(
                                      color: colors.textGrey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              Text(loc.loc('severe'),
                                  style: TextStyle(
                                      color: colors.textGrey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Fixed Save Button at the Bottom
          Positioned(
            bottom: 30,
            left: 25,
            right: 25,
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    elevation: 10,
                    shadowColor: colors.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20))),
                onPressed: _isSaving ? null : () => _saveDailyLog(colors, loc),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(loc.loc('save_checkin'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
