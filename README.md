# TriggerLens: An OCR-Driven Ingredient Analyzer for Powdered Drink Sachets for Acid Reflux Management

TriggerLens is an offline-first, mobile decision-support system designed to help individuals with hyperacidity and Gastroesophageal Reflux Disease (GERD) proactively manage their diets. Built with Flutter, Isar NoSQL, and Google ML Kit, the app bridges the "chemical literacy gap" by automatically analyzing the complex ingredients hidden on the back of commercial powdered drink sachets.

Traditional diet tracking apps require manual data entry and often treat every drink as an isolated event. TriggerLens solves this by using Edge OCR (Optical Character Recognition) to extract ingredients directly from physical sachets and immediately mapping those compounds against a localized database of clinical irritants.

Instead of relying on secret manufacturer percentages, the system utilizes the validated Remer-Manz Potential Renal Acid Load (PRAL) algorithm to mathematically calculate the systemic acid-producing potential of the drink based on its core macronutrients. It then scales this risk against the user's specific biological baseline (determined via a GerdQ-inspired onboarding assessment) to generate a personalized Acid Impact Verdict.

Crucially, TriggerLens implements a 6-hour continuous biological session timer, dynamically calculating the cumulative mucosal risk of multiple drinks consumed throughout the day against a strict daily acid cap.

Key Features:
1. Edge OCR with Glare Protection: Utilizes Google ML Kit running entirely on-device, featuring a custom 0.25 gibberish-ratio exception handler to filter out distortions caused by glossy, metallic sachet packaging.

2. Remer-Manz PRAL Integration: Mathematically computes systemic acid loads using the established PRAL algorithm, bypassing the need for proprietary brand formulas.

3. Session-Based Cumulative Tracking: Monitors acid accumulation over a 6-hour biological rolling window, preventing users from unknowingly stacking acidic triggers.

4. Zero-Latency Offline Architecture: Powered by Isar NoSQL for instantaneous local data retrieval, ensuring the core risk assessment features work 100% offline without cloud latency or subscription fees.

5. Context-Aware AI First Aid: Features a heavily constrained, Regex-bounded Gemini 3.5 AI chatbot (Tummy Buddy) to provide immediate, non-medical behavioral first aid during reflux flare-ups.

Architecture & Technologies:
Frontend: Flutter (Dart), Provider (State Management), Material 3 Design

Backend / Cloud (Sync Only): Firebase Authentication (Real SMTP Verification), Cloud Firestore

Local Database: Isar NoSQL

Machine Learning / Vision: Google ML Kit Text Recognition

Generative AI: Google Gemini 3.5-Flash-lite API
