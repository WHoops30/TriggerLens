import 'dart:developer';

class TriggerEngine {
  // A local target reference list of common chronic acidity triggers
  final List<String> acidityTriggers = [
    'citric acid',
    'ascorbic acid',
    'malic acid',
    'phosphoric acid',
    'artificial flavor',
    'high fructose corn syrup'
  ];

  /// Processes text strings, correcting common OCR misreads via fuzzy mapping
  String normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll('c1tric', 'citric') // Fixes common OCR 1 vs i errors
        .replaceAll('p4osphoric', 'phosphoric')
        .replaceAll(RegExp(r'\s+'), ' '); // Cleans up erratic spacing
  }

  /// Analyzes the string and returns items that match the trigger profile
  List<String> analyzeText(String rawText) {
    final cleanText = normalizeText(rawText);
    log("Processing cleaned text stream: $cleanText");

    return acidityTriggers
        .where((trigger) => cleanText.contains(trigger))
        .toList();
  }
}