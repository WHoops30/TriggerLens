import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/ui_helpers.dart';
import '../utils/app_localizations.dart';

class ConsumptionModal {
  /// Displays the modal and returns a map with the biological context:
  /// {'isEmptyStomach': bool, 'isDiluted': bool, 'portionMeasurement': String, 'portionCount': double}
  static Future<Map<String, dynamic>?> show(
      BuildContext context, String productName, String drinkCategory) async {
    bool isEmptyStomach = false;
    bool isDiluted = false;

    // Intelligent defaults based on the algorithm's detected drink category
    String selectedMeasurement = "Sachet";
    if (drinkCategory == "Herbal Tea") selectedMeasurement = "Tea Bag";
    if (drinkCategory == "Liquid Concentrate") selectedMeasurement = "Teaspoon";
    if (drinkCategory == "Heavy Powder") selectedMeasurement = "Tablespoon";

    double portionCount = 1.0;

    final List<String> measurementOptions = [
      "Sachet",
      "Tea Bag",
      "Tablespoon",
      "Teaspoon",
      "Drop/Dash"
    ];

    return showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setModalState) {
            final colors = AppColors.of(context);
            final loc = AppLocalizations.of(context);

            // Logic to hide the decimal counter for distinct items like sachets
            bool allowsCounter = selectedMeasurement == "Tablespoon" ||
                selectedMeasurement == "Teaspoon" ||
                selectedMeasurement == "Drop/Dash";

            // ==========================================
            // NEW: LIVE IMPACT CALCULATOR
            // ==========================================
            double liveMultiplier = portionCount;
            if (isEmptyStomach) liveMultiplier *= 1.2;
            if (isDiluted) liveMultiplier *= 0.85;

            Color multiplierColor = colors.successGreen;
            IconData multiplierIcon = Icons.check_circle_outline;

            if (liveMultiplier > 1.2) {
              multiplierColor = colors.errorRed;
              multiplierIcon = Icons.warning_amber_rounded;
            } else if (liveMultiplier > 1.0) {
              multiplierColor = colors.accentOrange;
              multiplierIcon = Icons.trending_up;
            } else if (liveMultiplier < 1.0) {
              multiplierColor = colors.primary;
              multiplierIcon = Icons.trending_down;
            }

            Widget buildChoiceRow(String title, String subtitle,
                bool isSelected, VoidCallback onTap) {
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primaryLight.withOpacity(0.15)
                        : colors.cardColor,
                    border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : (colors.isDark
                                ? Colors.white12
                                : Colors.grey.shade300),
                        width: 2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? colors.primary : Colors.grey),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: colors.textDark)),
                            const SizedBox(height: 2),
                            Text(subtitle,
                                style: TextStyle(
                                    fontSize: 11, color: colors.textGrey)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }

            String getMeasureKey(String measure) {
              if (measure == "Sachet") return "measure_sachet";
              if (measure == "Tea Bag") return "measure_tea_bag";
              if (measure == "Tablespoon") return "measure_tablespoon";
              if (measure == "Teaspoon") return "measure_teaspoon";
              if (measure == "Drop/Dash") return "measure_drop_dash";
              return measure;
            }

            return Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(35),
                      topRight: Radius.circular(35)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, -5))
                  ]),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                                color: colors.isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(10)))),
                    const SizedBox(height: 25),

                    Text(loc.loc('consuming_item', {'name': productName}),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: colors.primaryDark)),
                    const SizedBox(height: 5),
                    Text(loc.loc('quick_context'),
                        style: TextStyle(color: colors.textGrey, fontSize: 12)),
                    const SizedBox(height: 20),

                    // ==========================================
                    // LIVE MULTIPLIER BADGE
                    // ==========================================
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                          color: multiplierColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: multiplierColor.withOpacity(0.3))),
                      child: Row(
                        children: [
                          Icon(multiplierIcon,
                              color: multiplierColor, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Final Acid Multiplier",
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: colors.textDark)),
                                Text("x${liveMultiplier.toStringAsFixed(2)}",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: multiplierColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // ==========================================
                    // DYNAMIC PORTION SELECTOR
                    // ==========================================
                    Text(loc.loc('portion_size'),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: colors.textDark)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 10),
                      decoration: BoxDecoration(
                          color: colors.cardColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: colors.isDark
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                              width: 2)),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: selectedMeasurement,
                                dropdownColor: colors.cardColor,
                                icon: Icon(Icons.keyboard_arrow_down,
                                    color: colors.primaryDark),
                                items: measurementOptions.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(loc.loc(getMeasureKey(value)),
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: colors.primaryDark)),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    HapticFeedback.lightImpact();
                                    setModalState(() {
                                      selectedMeasurement = newValue;
                                      if (selectedMeasurement == "Sachet" ||
                                          selectedMeasurement == "Tea Bag") {
                                        portionCount = 1.0;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          if (allowsCounter) ...[
                            const SizedBox(width: 15),
                            Container(
                                width: 2,
                                height: 30,
                                color: colors.isDark
                                    ? Colors.white12
                                    : Colors.grey.shade200),
                            const SizedBox(width: 15),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                HapticFeedback.lightImpact();
                                if (portionCount > 0.5) portionCount -= 0.5;
                              }),
                              child: Icon(Icons.remove_circle_outline,
                                  color: colors.primaryDark, size: 28),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 35,
                              child: Center(
                                child: Text(portionCount.toStringAsFixed(1),
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: colors.primary)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => setModalState(() {
                                HapticFeedback.lightImpact();
                                portionCount += 0.5;
                              }),
                              child: Icon(Icons.add_circle_outline,
                                  color: colors.primaryDark, size: 28),
                            ),
                          ]
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // ==========================================
                    // STOMACH STATE & PREPARATION
                    // ==========================================
                    Text(loc.loc('stomach_state'),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: colors.textDark)),
                    const SizedBox(height: 10),
                    buildChoiceRow(
                        loc.loc('empty_stomach'),
                        loc.loc('empty_stomach_desc'),
                        isEmptyStomach,
                        () => setModalState(() => isEmptyStomach = true)),
                    const SizedBox(height: 10),
                    buildChoiceRow(
                        loc.loc('just_ate'),
                        loc.loc('just_ate_desc'),
                        !isEmptyStomach,
                        () => setModalState(() => isEmptyStomach = false)),
                    const SizedBox(height: 25),

                    Text(loc.loc('preparation'),
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: colors.textDark)),
                    const SizedBox(height: 10),
                    buildChoiceRow(
                        loc.loc('standard_mix'),
                        loc.loc('standard_mix_desc'),
                        !isDiluted,
                        () => setModalState(() => isDiluted = false)),
                    const SizedBox(height: 10),
                    buildChoiceRow(loc.loc('diluted'), loc.loc('diluted_desc'),
                        isDiluted, () => setModalState(() => isDiluted = true)),
                    const SizedBox(height: 35),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20))),
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          Navigator.pop(context, {
                            'isEmptyStomach': isEmptyStomach,
                            'isDiluted': isDiluted,
                            'portionMeasurement': selectedMeasurement,
                            'portionCount': allowsCounter ? portionCount : 1.0,
                          });
                        },
                        child: Text(loc.loc('save_and_consume'),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          });
        });
  }
}
