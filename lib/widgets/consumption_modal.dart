import 'package:flutter/material.dart';
import '../utils/ui_helpers.dart';

class ConsumptionModal {
  /// Displays the modal and returns a map with the biological context:
  /// {'isEmptyStomach': bool, 'isDiluted': bool}
  static Future<Map<String, bool>?> show(
      BuildContext context, String productName) async {
    bool isEmptyStomach = false;
    bool isDiluted = false;

    return showModalBottomSheet<Map<String, bool>>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setModalState) {
            Widget buildChoiceRow(String title, String subtitle,
                bool isSelected, VoidCallback onTap) {
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLight.withOpacity(0.2)
                        : Colors.white,
                    border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        width: 2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected ? AppColors.primary : Colors.grey),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 20),
                  Text('Consuming $productName',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark)),
                  const Text('Quick context for the algorithm:',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 20),
                  const Text('Stomach State',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  buildChoiceRow(
                      'Empty Stomach',
                      'First thing in the morning / fasted',
                      isEmptyStomach,
                      () => setModalState(() => isEmptyStomach = true)),
                  const SizedBox(height: 10),
                  buildChoiceRow(
                      'Just Ate / Full',
                      'Consumed with or after a meal',
                      !isEmptyStomach,
                      () => setModalState(() => isEmptyStomach = false)),
                  const SizedBox(height: 25),
                  const Text('Preparation',
                      style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  buildChoiceRow('Standard Mix', 'Prepared normally',
                      !isDiluted, () => setModalState(() => isDiluted = false)),
                  const SizedBox(height: 10),
                  buildChoiceRow('Diluted', 'Added extra water or milk',
                      isDiluted, () => setModalState(() => isDiluted = true)),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20))),
                      onPressed: () {
                        Navigator.pop(context, {
                          'isEmptyStomach': isEmptyStomach,
                          'isDiluted': isDiluted,
                        });
                      },
                      child: const Text('Save & Consume',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18)),
                    ),
                  )
                ],
              ),
            );
          });
        });
  }
}
