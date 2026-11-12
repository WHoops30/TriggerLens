import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'en';
  String get currentLanguage => _currentLanguage;

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language_code') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    notifyListeners();
  }
}

class LanguageDictionary {
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Welcome & Auth Screens
      'get_started': 'Get Started',
      'create_account': 'Create Account',
      'already_have_account': 'Log In to Existing Account',
      'pre_login_settings': 'Display Settings',
      'customize_experience': 'Customize your language preference',
      'language': 'Language',
      'log_in_title': 'Log In to TriggerLens',
      'email_address': 'Email Address',
      'invalid_email_pass': 'Invalid email or password.',
      'password': 'Password',
      'required_field': 'Required',
      'forgot_password': 'Forgot Password?',
      'log_in_btn': 'Log In',
      'or': 'or',
      'continue_google': 'Continue with Google',
      'new_to_triggerlens': 'New to TriggerLens?',
      'sign_up_link': 'Sign Up',
      'press_hold_unlock': 'Press and hold to unlock',

      // Theme & Value Proposition Translations
      'val_secure_sync': 'Secure Medical Sync',
      'val_secure_sync_desc': 'Back up your GERD limits safely to the cloud.',
      'val_personalize': 'Personalized Experience',
      'val_personalize_desc': 'Unlock custom themes and language preferences.',
      'val_analytics': 'Clinical Analytics',
      'val_analytics_desc': 'Track your personalized acid tolerance daily.',
      'customization': 'Customization',
      'appearance_theme': 'Appearance & Theme',
      'live_preview': 'Live Preview',
      'theme_active': 'Theme Active',
      'theme_preview_desc': 'This is how your scanner UI will look.',
      'sample_button': 'Sample Button',
      'display_mode': 'Display Mode',
      'dark_mode': 'Dark Mode',
      'dark_mode_desc': 'Easier on the eyes in low light.',
      'accent_color': 'Accent Color',

      // Sign Up Additions
      'create_your_account': 'Create Your Account',
      'full_name': 'Full Name',
      'confirm_password': 'Confirm Password',
      'min_6_chars': 'Min 6 chars',
      'mismatch': 'Mismatch',
      'agree_to_privacy': 'You must agree to the Data Privacy Policy.',
      'read_understood': 'I have read and understood the ',
      'data_privacy_policy': 'Data Privacy Policy',
      'consent_processing':
          ' and consent to the processing of my data in accordance with the DPA of 2012. ',
      'learn_more': 'Learn More',
      'sign_up': 'Sign Up',
      'already_have_account_login': 'Already have an account? ',

      // Password Recovery & Google Auth
      'err_pass_min_6': 'Password must be at least 6 characters.',
      'err_pass_mismatch': 'Passwords do not match.',
      'success_app_password': 'App Password Set Successfully!',
      'error_msg': 'Error: {message}',
      'secure_account': 'Secure Your Account',
      'google_password_desc':
          'Since you signed in with Google, please set a backup password for TriggerLens. This allows you to log in via email and use password recovery in the future.',
      'create_password_hint': 'Create Password',
      'save_continue': 'Save & Continue',
      'forgot_password_title': 'Forgot Password',
      'forgot_password_desc':
          'Please enter your Email Address to reset the password.',
      'invalid_email_format': 'Enter a valid email',
      'reset_password_btn': 'Reset Password',
      'enter_otp': 'Enter OTP',
      'enter_otp_desc':
          'Please enter the OTP sent to your registered Email Address.',
      'verify_code': 'Verify Code',
      'no_otp_yet': "Haven't got the OTP yet? ",
      'resend_otp': 'Resend OTP',
      'password_reset_title': 'Password Reset',
      'password_reset_success_desc':
          'Your password has been successfully reset. Click confirm to set a new password.',
      'confirm_btn': 'Confirm',
      'set_new_password': 'Set a New Password',
      'set_new_password_desc':
          'Create a new password. Ensure it differs from previous ones for security.',
      'enter_new_password': 'Enter your New Password',
      'reenter_password': 'Re-enter Password',
      'successful_title': 'Successful',
      'successful_reset_desc':
          'Congratulations! Your password has been\nsuccessfully updated. Click continue to Log In.',
      'continue_btn': 'Continue',

      // Core & Dashboard
      'trigger': 'Trigger',
      'lens': 'Lens',
      'hi': 'Hi',
      'cumulative_risk': 'ACTIVE STOMACH LOAD',
      'hr_mn_sec': 'HR   MN   SEC',
      'stomach_empty': 'Stomach is empty',
      'digesting': 'Currently Digesting: {drink}',
      'queue_count': '(+{count} other items in queue)',
      'target_strict': 'LIMIT: STRICT (<= 0.0)',
      'cap': 'DAILY LIMIT: {limit} POINTS',
      'coffee_allowance':
          'You have about {cups} standard coffee cups of acid allowance left today.',
      'scans': 'Scans',
      'consumed': 'Consumed',
      'symptoms': 'Symptoms',
      'scan_sachet': 'Scan a sachet',
      'recent_scans': 'Recent Scans',
      'view_all': 'View all',
      'no_recent_scans': 'No recent scans found.',
      'consumed_on': 'Consumed - {date}',
      'offline_warning':
          'Offline Mode. Scanner & Pantry are ready, but Tummy Buddy is resting.',
      'tooltip_daily_limit':
          'This is your personalized maximum acid allowance for the day. Staying under this limit prevents reflux flare-ups.',
      'tooltip_cumulative':
          'This shows the total acid load currently active in your stomach. It naturally decreases as you digest over 6 hours.',

      // Notifications & Tips (NEW)
      'updates_tips': 'Updates & Tips',
      'no_new_notifications': 'No new notifications.',
      'quick_health_tip': 'Quick Health Tip',
      'stress_penalty_active': 'Stress Penalty Active',
      'stress_penalty_desc':
          'Your acid tolerance is temporarily reduced by 15% to protect your sensitive stomach.',
      'threshold_warning': 'Threshold Warning',
      'threshold_warning_desc':
          'You are at {percent}% of your daily limit. Switch to water for your next drink!',
      'ready_for_drink': 'Ready for a drink?',
      'scan_prompt_desc':
          'Scan a new sachet to check its acid load before consuming.',
      'test_push': 'Test Push',

      // GERD Facts (NEW)
      'tip_0':
          "Sleeping on your left side helps keep stomach acid away from your esophagus.",
      'tip_1':
          "Chewing sugar-free gum increases saliva, which naturally neutralizes acid.",
      'tip_2':
          "Eating smaller, more frequent meals reduces pressure on your stomach valve.",
      'tip_3':
          "Avoid lying down for at least 3 hours after eating or drinking.",
      'tip_4': "Tight clothing around your waist can push stomach acid upward.",
      'tip_5':
          "Drinking water slowly is better than chugging, which can overfill the stomach.",
      'tip_6':
          "Elevating the head of your bed by 6-8 inches can prevent nighttime reflux.",
      'tip_7':
          "Stress can increase your stomach's sensitivity to small amounts of acid.",
      'tip_8':
          "Wait 30 minutes after a meal before exercising to avoid acid splash.",
      'tip_9':
          "Bananas and melons are naturally low-acid fruits that can soothe the stomach.",
      'tip_10': "Oatmeal is excellent for absorbing excess stomach acid.",
      'tip_11':
          "Smoking weakens the valve that keeps stomach acid out of the esophagus.",
      'tip_12':
          "Carbonated beverages increase stomach pressure and trigger burping.",
      'tip_13':
          "Aloe vera juice (unsweetened) can help coat and soothe the esophageal lining.",
      'tip_14':
          "Ginger tea is a natural anti-inflammatory that aids digestion.",
      'tip_15':
          "Late-night snacking is a major trigger for morning acid reflux.",
      'tip_16':
          "Excess weight puts extra pressure on your abdomen, pushing acid up.",
      'tip_17':
          "Peppermint can actually relax the stomach valve and worsen reflux. Use caution!",
      'tip_18':
          "Drinking a glass of lukewarm water in the morning helps flush the digestive system.",
      'tip_19':
          "Acid reflux isn't always heartburn—chronic coughing or a sore throat can be symptoms.",

      // Profile & Settings
      'tummy_friend': 'Tummy Friend',
      'no_email_connected': 'No email connected',
      'total_scans': 'Total Scans',
      'safe_drinks': 'Safe Drinks',
      'triggers': 'Triggers',
      'medical_demographics': 'Medical Demographics',
      'clinical_status': 'Clinical Status',
      'preventative': 'Preventative',
      'age_group': 'Age Group',
      'primary_goal': 'Primary Goal',
      'track_limit': 'Track my limit',
      'todays_tolerance': 'TODAY\'S TOLERANCE',
      'highly_sensitive': 'Highly Sensitive',
      'highly_sensitive_desc':
          'Your tolerance is severely restricted due to recent symptoms or stress. Hydrate strictly with water.',
      'slightly_sensitive': 'Slightly Sensitive',
      'slightly_sensitive_desc':
          'Your acid limit is slightly reduced today. Stick to milder drinks if possible.',
      'optimal_tolerance': 'Optimal Tolerance',
      'optimal_tolerance_desc':
          'Your stomach is operating at its full personal baseline today. You have standard flexibility.',
      'standard_baseline': 'Standard Baseline:',
      'your_active_limit': 'Your Active Limit:',
      'coffee_cups': 'coffee cups',
      'verified_personal_triggers': 'Your Verified Personal Triggers',
      'your_specific_triggers': 'Your Specific Triggers',
      'no_recent_symptoms': 'No recent symptoms',
      'no_verified_triggers':
          'No verified triggers yet. Ingredients will only appear here if they are linked to a logged clinical symptom.',
      'frequent_symptoms': 'Frequent Symptoms',
      'no_symptoms_logged': 'No symptoms logged. Keep up the good work.',
      'recalibrate_phase': 'Recalibrate Phase',
      'logged_times': 'You have logged "{name}" {count} times.',
      'settings': 'Settings',
      'account': 'Account',
      'edit_profile': 'Edit Profile & Avatar',
      'pro_scanner_prefs': 'Pro Scanner Preferences',
      'batch_scan_mode': 'Batch Scanning Mode',
      'batch_scan_mode_desc':
          'Scan groceries consecutively without returning to the menu.',
      'strict_risk_filter': 'Strict Risk Filter',
      'strict_risk_filter_desc':
          'Treats moderate (Yellow) triggers as high-risk (Red).',
      'haptic_feedback': 'Haptic Feedback',
      'haptic_feedback_desc': 'Vibrate on successful scans and alerts.',
      'auto_flashlight': 'Auto-Flashlight',
      'auto_flashlight_desc':
          'Turn on flashlight automatically when opening the scanner.',
      'security_legal': 'Security & Legal',
      'medical_privacy_hub': 'Medical Privacy & Data Hub',
      'info_support': 'Information & Support',
      'log_out': 'Log Out',
      'log_out_q': 'Log Out?',
      'log_out_desc': 'Are you sure you want to log out of your account?',
      'cancel': 'Cancel',

      // Avatar & Profile Edits
      'update_profile_pic': 'Update Profile Picture',
      'take_photo': 'Take a Photo',
      'choose_gallery': 'Choose from Gallery',
      'choose_preset_avatar': 'Or Choose a Preset Avatar',
      'avatar_updated': 'Avatar Updated!',
      'update_failed': 'Update Failed',
      'confirm_name_change': 'Confirm Name Change',
      'confirm_name_desc':
          "Are you sure you want to change your display name to '{name}'?",
      'save_changes': 'Save Changes',
      'name_updated': 'Display name updated successfully!',
      'send_reset_email': 'Send Reset Email?',
      'send_reset_desc': 'We will send a password reset link to:',
      'send_email': 'Send Email',
      'reset_link_sent': 'Secure reset link sent to {email}',
      'account_profile': 'Account Profile',
      'display_name': 'Display Name',
      'registered_email': 'Registered Email',
      'no_email_associated': 'No email associated',
      'send_password_reset': 'Send Password Reset Email',

      // Privacy Hub & Export
      'medical_data_hub_title': 'Medical Data &\nPrivacy Hub',
      'storage_policy': 'Storage Policy',
      'cloud_sync': 'Cloud Sync & Backup',
      'cloud_sync_desc':
          'Store data securely in the cloud to access across devices. Turning this off restricts data strictly to this phone.',
      'anonymous_analytics': 'Anonymous Analytics',
      'anonymous_analytics_desc':
          'Help TriggerLens improve by sharing non-identifiable scan speeds.',
      'data_portability': 'Data Portability (R.A. 10173)',
      'request_data_export': 'Request Data Export',
      'request_data_export_desc':
          'Download a CSV copy of your historical data.',
      'danger_zone': 'Danger Zone',
      'erase_local_logs': 'Erase Local Health Logs',
      'erase_local_logs_desc':
          'Clears scans and heuristic history from this device only.',
      'erase_account': 'Erase Account & Cloud Data',
      'erase_account_desc':
          'Permanently destroy your entire account and all cloud backups.',
      'disable_cloud_backup_q': 'Disable Cloud Backup?',
      'disable_cloud_desc':
          'If you disable Cloud Sync, your medical data will only live on this specific device. If you uninstall the app or log in on a new phone, all your scans and heuristic history will be permanently lost.\n\nAre you sure?',
      'disable_sync': 'Disable Sync',
      'export_failed': 'Export failed',
      'erase_local_logs_q': 'Erase Local Device Logs?',
      'erase_local_desc':
          'This will instantly delete all food scans and heuristic data from this phone. You will remain logged in.\n\nThis cannot be undone.',
      'local_data_erased': 'Local Device Data Erased.',
      'erase_local_data': 'Erase Local Data',
      'delete_account_q': 'Delete Account?',
      'delete_account_desc':
          'This is the nuclear option. We will wipe all local data from this device, destroy your cloud backup, and permanently delete your authentication record.\n\nAre you absolutely sure?',
      'security_requirement_delete':
          'Security Requirement: Please log out and log back in to verify identity before deleting.',
      'permanently_delete': 'PERMANENTLY DELETE',
      'information': 'Information',
      'about_triggerlens': 'About TriggerLens',
      'version_desc': 'Automated ingredient analysis system.',
      'help_support': 'Help & Support',
      'how_to_use_scanner': 'How to Use the Scanner',
      'how_to_use_scanner_desc': 'Position sachets for accurate reading.',
      'legal_safety': 'Legal & Safety',
      'medical_disclaimer': 'Medical Disclaimer',
      'medical_disclaimer_desc': 'Not a replacement for medical diagnosis.',
      'csv_date_scanned': 'Date Scanned',
      'csv_product_name': 'Product Name',
      'csv_risk_level': 'Risk Level',
      'csv_acid_score': 'Acid Score',
      'csv_symptoms_logged': 'Symptoms Logged',
      'csv_none': 'None',
      'csv_export_title': 'My TriggerLens Data Export',

      // Privacy Policy
      'privacy_policy_title': 'Data Privacy Notice',
      'privacy_policy_content':
          'TriggerLens is committed to protecting your medical and personal data in accordance with the Data Privacy Act of 2012 (R.A. 10173).\n\n1. Data Collection\nWe collect demographic data (age, clinical status) and logged symptoms to personalize your acid reflux thresholds. This is used solely to generate your dynamic daily limit.\n\n2. Image Processing\nImages captured by the OCR scanner are processed securely via Google ML Kit. We do not permanently store or share photos of your environment or food.\n\n3. Cloud Sync\nIf enabled, your data is securely synced to your personal cloud account. You retain full ownership and can permanently erase your local and cloud data at any time via the Medical Privacy Hub.\n\n4. Usage Analytics\nWe may collect anonymous usage data (like average scan speeds) to improve our algorithms. No personally identifiable information is ever shared with third parties.',
      'i_understand_btn': 'I Understand',

      // Scanner & Diagnostics
      'analyzing_env': 'Analyzing environment...',
      'move_closer': 'Move closer to the ingredients list.',
      'text_distorted': 'Text distorted. Please flatten the curved sachet.',
      'glare_detected': 'Glare detected. Tilt the sachet away from the light.',
      'scanning_text': 'Scanning text blocks...',
      'ingredients_detected': 'Ingredients detected! Locking on...',
      'need_diff_approach': 'Need a different approach?',
      'shiny_curved_desc':
          'Shiny or curved sachets can be tricky for the auto-scanner. Would you like to try these other options?',
      'manual_shutter': 'Manual Shutter',
      'take_photo_desc': 'Take a photo and crop it manually',
      'type_ingredients': 'Type Ingredients',
      'type_ingredients_desc': 'Manually type the text',
      'keep_trying_auto': 'Keep Trying Auto-Scan',

      // Pantry, Results & Filters (NEWLY MAPPED)
      'filters': 'Filters',
      'sort_newest': 'Newest',
      'sort_oldest': 'Oldest',
      'sort_highest_risk': 'Highest Risk',
      'sort_lowest_risk': 'Lowest Risk',
      'sort_a_z': 'A-Z',
      'digestion_complete_title': 'Digestion Complete',
      'digestion_complete_body':
          'It has been 6 hours since you consumed {name}. Your stomach load has reset.',
      'acid_buffer_reminder': 'Acid Buffer Reminder',
      'acid_buffer_body':
          'Since you had {name} on an empty stomach, slowly sip some water now to coat your stomach lining.',
      'symptom_checkin_title': 'Symptom Check-In',
      'symptom_checkin_body':
          'How is your stomach feeling after drinking {name}? Tap to log any discomfort.',
      'item_consumed_logged': 'Logged: Consumed {name}!',
      'saved_to_pantry': 'Saved to Digital Pantry!',
      'name_this_drink': 'Name This Drink',
      'eg_nescafe': 'e.g., Nescafe 3-in-1',
      'save_name': 'Save Name',
      'unnamed': 'Unnamed',
      'manual_entry': 'Manual Entry',
      'type_ingredients_hint': 'Type ingredients separated by commas...',
      'analyze': 'Analyze',

      // Symptoms
      'log_a_symptom': 'Log a Symptom',
      'track_how_you_feel': 'Track how you feel after this product',
      'log_clinical_symptom': 'Log Clinical Symptom',
      'log_symptom_desc':
          'Select the option that best describes what you are feeling right now. This helps TriggerLens accurately map your biological triggers.',
      'what_symptoms': 'What symptoms are you currently experiencing?',
      'severity_scale_q':
          'On a scale of 1 to 10, how severe is your discomfort right now?',
      'save_log': 'Save Log',
      'save_biological_log': 'Save Biological Log',
      'symp_heartburn': 'Heartburn',
      'desc_heartburn': 'Burning pain behind your chest bone',
      'symp_acid_regurgitation': 'Acid Regurgitation',
      'desc_acid_regurgitation': 'Sour liquid splashing into throat',
      'symp_dyspepsia': 'Dyspepsia',
      'desc_dyspepsia': 'Heavy, bloated, or painful upper stomach',
      'symp_globus_sensation': 'Globus Sensation',
      'desc_globus_sensation': 'Feeling like a lump is stuck in throat',
      'symp_nausea': 'Nausea',
      'desc_nausea': 'Feeling sick to your stomach',
      'symp_excessive_burping': 'Excessive Burping',
      'desc_excessive_burping': 'Trapped gas forcing its way up',
      'symp_none': 'None',
      'desc_none': 'I feel perfectly fine!',
      'symp_bloating': 'Bloating',
      'symp_burping': 'Burping',
      'symp_cramps': 'Cramps',
      'symp_chest_pain': 'Chest Pain',
      'symp_acidic_taste': 'Acidic Taste',
      'symp_sore_throat': 'Sore Throat',
      'symp_dry_cough': 'Dry Cough',

      // Veridcts & UI
      'high_danger': 'High Danger',
      'moderate_risk': 'Moderate Risk',
      'safe_to_consume': 'Safe to Consume',
      'scan_again': 'Scan Again',
      'save_to_pantry_btn': 'Save to Pantry',
      'consume_now': 'Consume Now',
      'auto_scan_mode': 'Auto-Scan Mode',
      'manual_entry_analysis': 'Manual Entry Analysis',
      'extracting_text': 'Extracting text via Google ML Kit...',
      'category_label': 'Category:',
      'acid_impact_verdict': 'Acid Impact Verdict',
      'acid_points': 'Acid Points',
      'dashboard_impact': 'Dashboard Impact',
      'percent_daily_cap': '{percent}% of Daily Limit',
      'potential_clinical_irritants': 'Potential Clinical Irritants',
      'raw_ocr_data': 'Raw OCR System Data',
      'tap_to_edit_ocr':
          'Tap to edit misread words. You must hit Recalibrate to update the score.',
      'no_text_provided': 'No text provided.',
      'recalibrating': 'Recalibrating...',
      'recalibrate_analysis': 'Recalibrate Analysis',
      'analysis_recalibrated': 'Analysis successfully recalibrated!',
      'pantry_item_recalibrated': 'Pantry item successfully recalibrated!',
      'log_symptom_btn': 'Log Symptom',
      'first_aid_coach': 'First Aid Coach',
      'gallery': 'Gallery',
      'type_ingredients_manually': 'Type Ingredients Manually',
      'how_it_works': 'How it works',
      'how_it_works_desc':
          'Point the camera at a powdered drink sachet. The scanner will automatically detect the ingredients and isolate them for analysis. No need to press a button unless the scanner fails.',

      // Digital Pantry
      'digital_pantry': 'Digital Pantry',
      'search_inventory': 'Search your inventory...',
      'all': 'All',
      'favorites': 'Favorites',
      'safe': 'Safe',
      'med': 'Moderate',
      'high': 'High',
      'pantry_empty_title': 'Your Pantry is Empty!',
      'pantry_empty_desc':
          'Tap the scanner below to analyze and save your first drink. Your safe favorites and risky triggers will live here.',
      'logged_on': 'Logged on {date}',
      'historical_impact': 'Historical Impact',
      'portion_label': 'Portion: {count} {measure}',
      'consumed_empty_stomach': 'Consumed on Empty Stomach',
      'consumed_with_food': 'Consumed with Food',
      'clinical_symptoms': 'Clinical Symptoms',
      'pantry_saved_info':
          "This item is saved in your pantry. Tap 'Consume' below when you drink it to start your digestion timer and unlock symptom tracking.",
      'delete': 'Delete',
      'consume_btn': 'Consume',
      'drink_again': 'Drink Again',
      'saved_only': 'SAVED ONLY',
      'exceeds_daily_cap': '⚠️ Exceeds Daily Acid Limit',

      // Drink Categories
      'herbal_tea': 'Herbal Tea',
      'liquid_concentrate': 'Liquid Concentrate',
      'heavy_powder': 'Heavy Powder',
      'general_beverage': 'General Beverage',

      // AI Coach
      'greeting_general':
          'Hi {name}! I\'m Tummy Buddy ✨ How can I help you today?',
      'greeting_scanner':
          'Hi {name}! I see you logged feeling {symptom} after having {product}. I am so sorry! Do you need some gentle tips to feel better right now? 🩹',
      'greeting_insights':
          'Hi {name}! I was just looking at your recent insights. Let\'s figure out how we can keep your daily acid load under control! 📊',
      'tummy_buddy': 'Tummy Buddy',
      'insight_analyst': 'Insight Analyst',
      'chat_auto_delete_notice':
          'Chats automatically delete after 14 days. Long-press any message to delete it now.',
      'chat_hint': 'Tell Tummy Buddy how you feel...',
      'tummy_buddy_typing': 'Tummy Buddy is typing...',
      'clear_chat_q': 'Clear Chat?',
      'clear_chat_desc':
          'This will permanently delete your conversation memory from this device.',
      'delete_message_q': 'Delete Message?',
      'delete_message_desc':
          'Are you sure you want to delete this specific message?',
      'error_no_internet':
          'Oops! I need an active internet connection to think. Please check your Wi-Fi or data! 🫧',
      'error_medical_emergency':
          '⚠️ This sounds like a medical emergency. I am not a doctor. Please stop using this app and seek immediate professional medical attention, go to the nearest hospital, or call emergency services right away.',
      'error_connection_hiccup':
          'My connection hiccuped for a second! Tap send again and I’ll help right away. 🧸',
      'error_server_unreachable':
          'Tummy Buddy is having trouble reaching the server right now. Take a slow sip of water, and try sending your message again in a moment! 🍵✨',

      // Onboarding
      'skip': 'Skip',
      'onboard_q1_title': 'What brings you to TriggerLens today?',
      'diagnosed_gerd': 'Diagnosed GERD',
      'diagnosed_gerd_desc':
          'I have been formally diagnosed by a doctor. We will apply a strict, protective baseline.',
      'occasional_reflux': 'Occasional Reflux',
      'occasional_reflux_desc':
          'I experience heartburn or acid reflux from time to time. We will help identify your patterns.',
      'preventative_desc':
          'I want to monitor my stomach health and prevent issues before they start.',
      'onboard_q2_title': 'What is your age group?',
      'under_18': 'Under 18',
      'under_18_desc':
          'Younger digestion systems have higher resilience, but building safe habits is key.',
      'age_18_25': '18-25',
      'age_18_25_desc':
          'Prime metabolic age. We will set a balanced, standard acid baseline.',
      'age_26_45': '26-45',
      'age_26_45_desc':
          'Metabolism and LES strength begin to shift. We will adjust your limit to match.',
      'age_46_older': '46 and older',
      'age_46_older_desc':
          'Natural age-related changes require a stricter, safer acid limit. We\'ve got you covered.',
      'onboard_q3_title': 'How often do you experience discomfort?',
      'almost_every_day': 'Almost every day',
      'almost_every_day_desc':
          'Chronic exposure requires a strict recovery routine. We will monitor you closely.',
      'few_times_a_week': 'A few times a week',
      'few_times_a_week_desc':
          'Moderate irritation. We will help you identify what is causing the flare-ups.',
      'rarely': 'Rarely',
      'rarely_desc':
          'Occasional discomfort. We will focus purely on finding your outlier triggers.',
      'onboard_q4_title': 'What is your primary goal?',
      'discover_hidden_triggers': 'Discover hidden triggers',
      'discover_hidden_triggers_desc':
          'We\'ll use OCR to flag hidden acidic compounds before you drink them.',
      'prevent_nighttime_reflux': 'Prevent nighttime reflux',
      'prevent_nighttime_reflux_desc':
          'We\'ll focus on your evening beverage cut-offs and late-night loads.',
      'track_limit_desc':
          'We\'ll give you a dynamic daily Acid Point allowance to keep your stomach balanced.',
      'calibrate_engine': 'Calibrate Engine',
      'next': 'Next',
      'are_you_sure': 'Are you sure?',
      'skip_warning_desc':
          'Skipping calibration will apply a generic acid threshold. For safe, personalized medical insights, we highly recommend answering these questions.',
      'skip_anyway': 'Skip Anyway',
      'continue_quiz': 'Continue Quiz',
      'ready_to_commit': 'Are you ready to commit to a healthier lifestyle?',
      'commit_desc':
          'Your personalized biological profile is ready. Hold your thumb below to seal your commitment and calibrate your engine.',
      'press_hold_commit': 'PRESS AND HOLD TO COMMIT',

      // Path Screen & Assessment
      'choose_your_path': 'Choose Your\nPath',
      'path_diagnosed_title': 'I have a Diagnosis',
      'path_diagnosed_desc':
          'A doctor has officially confirmed I have GERD or acid reflux.',
      'path_screen_title': 'I want to screen myself',
      'path_screen_desc':
          'I want to screen my reactions to powdered beverages and identify my acidic triggers.',
      'gerd_clinical_assessment': 'Clinical Assessment',
      'gerd_assessment_desc':
          'To establish a safe baseline, we need to understand the current severity of your diagnosis.',
      'gerd_q1':
          '1. How often do you wake up at night due to heartburn or acid reflux?',
      'gerd_q2':
          '2. How often do you rely on antacids or prescribed PPI medications?',
      'gerd_q3':
          '3. Do you experience dysphagia (difficulty or pain when swallowing)?',
      'opt_never': 'Never',
      'opt_sometimes': 'Sometimes',
      'opt_often': 'Often',
      'opt_rarely': 'Rarely / None',
      'opt_otc_occ': 'Occasional OTC',
      'opt_daily_rx': 'Daily Prescribed',
      'opt_no': 'No',
      'opt_mild': 'Mild / Sometimes',
      'opt_severe': 'Severe / Frequent',
      'generate_profile': 'Generate Profile',
      'health_assessment': 'Health Assessment',
      'gerdq_assessment': 'GerdQ Assessment',
      'gerdq_desc':
          'Please indicate how often you have experienced the following symptoms during the last 7 days.',
      '0_days': '0 Days',
      '1_day': '1 Day',
      '2_3_days': '2-3 Days',
      '3_days': '3 Days',
      '4_7_days': '4-7 Days',
      '7_days': '7 Days',
      '14_days': '14 Days',
      '30_days': '30 Days',
      'answer_all_questions': 'Please answer all 6 questions to proceed.',
      'calc_risk_profile': 'Calculate My Risk Profile',
      'gerdq_q1':
          '1. How often did you have a burning feeling behind your breastbone (heartburn)?',
      'gerdq_q2':
          '2. How often did stomach contents move upwards to your throat or mouth (regurgitation)?',
      'gerdq_q3':
          '3. How often did you have pain in the center of your upper stomach?',
      'gerdq_q4': '4. How often did you feel nauseated?',
      'gerdq_q5':
          '5. How often did you have difficulty getting a good night\'s sleep because of your heartburn and/or regurgitation?',
      'gerdq_q6':
          '6. How often did you take additional medication for your heartburn and/or regurgitation, other than what your physician prescribed (if any)?',

      // Journal Screen
      'daily_checkin': 'Daily Check-in',
      'how_tummy_feeling': 'How is your tummy feeling today?',
      'category_digestion': 'Digestion',
      'category_pain_discomfort': 'Pain & Discomfort',
      'category_throat_mouth': 'Throat & Mouth',
      'overall_discomfort': 'Overall Discomfort',
      'none': 'None',
      'severe': 'Severe',
      'save_checkin': 'Save Check-in',
      'daily_symptoms_logged': 'Daily symptoms logged successfully! ✨',

      // Insights Additions
      'insights': 'Insights',
      'profile_label': 'Profile:',
      '7_day_clinical_trends': '7-Day Clinical Trends',
      'all_time_lifestyle_patterns': 'All-Time Lifestyle Patterns',
      'most_vulnerable': 'Most Vulnerable',
      'empty_stomach_label': 'Empty Stomach',
      'flare_ups_count': '{count} Flare-ups',
      'primary_clinical_symptom': 'Primary Clinical Symptom',
      'symptom_logs_count': '{name} ({count} logs)',
      'not_enough_data_triggers':
          'Not enough data to map specific chemical patterns yet.',
      'ingredients_repeatedly_appear':
          'These ingredients repeatedly appear right before a symptom is logged:',
      'incidents_count': '{count} Incidents',
      'session_tracker': 'Session Tracker',
      'currently_digesting': 'Currently Digesting: {drink}',
      'queue_position': 'Item {current} of {total}',
      'history_log': 'History Log',
      'entries_count': '{count} entries',
      'no_drinks_logged': 'No drinks logged in this timeframe.',
      'see_more': 'See More',
      'export_clinical_report': 'Export Clinical Report',
      'download_pdf': 'Download PDF',
      'save_copy_device': 'Save a copy directly to your device',
      'print_pdf': 'Print PDF',
      'send_wireless_printer': 'Send directly to a wireless printer',
      'share_pdf': 'Share PDF',
      'send_via_social': 'Send via Email, Viber, or Messenger',
      'downloaded_to_documents': 'Downloaded to Documents: {file}',
      'no_insights_yet': 'No Insights Yet',
      'no_insights_desc':
          'Your biological trends, flare-up correlations, and interactive charts will appear here once you start consuming drinks from your Pantry.\n\nTap the Scanner below to begin!',
      'cap_label': 'DAILY LIMIT',
      'today': 'Today',
      'todays_breakdown': "Today's Breakdown",
      'no_drinks_this_day': 'No drinks consumed on this day.',
      'logged_symptom_list': 'Logged: {symptoms}',
      'not_enough_data': 'Not enough data',
    },
    'tl': {
      // Welcome & Auth Screens
      'get_started': 'Magsimula Na',
      'create_account': 'Gumawa ng Account',
      'already_have_account': 'Mag-Log In sa Account',
      'pre_login_settings': 'Mga Display Setting',
      'customize_experience': 'Piliin ang wika na gusto mong gamitin',
      'language': 'Wika',
      'log_in_title': 'Mag-Log In sa TriggerLens',
      'email_address': 'Email Address',
      'invalid_email_pass': 'Mali ang email o password.',
      'password': 'Password',
      'required_field': 'Kailangan ito',
      'forgot_password': 'Nakalimutan ang Password?',
      'log_in_btn': 'Mag-Log In',
      'or': 'o',
      'continue_google': 'Magpatuloy gamit ang Google',
      'new_to_triggerlens': 'Bago sa TriggerLens?',
      'sign_up_link': 'Mag-Sign Up',
      'press_hold_unlock': 'Pindutin at idiin para i-unlock',

      // Theme & Value Proposition Translations
      'val_secure_sync': 'Ligtas na Cloud Sync',
      'val_secure_sync_desc':
          'I-save ang iyong GERD data nang ligtas sa cloud.',
      'val_personalize': 'I-customize ang App',
      'val_personalize_desc': 'Pumili ng sariling kulay at wika para sa app.',
      'val_analytics': 'Bantayan ang Kalusugan',
      'val_analytics_desc': 'Tingnan ang iyong acid limit araw-araw.',
      'customization': 'Customization',
      'appearance_theme': 'Hitsura at Tema',
      'live_preview': 'Live Preview',
      'theme_active': 'Aktibong Tema',
      'theme_preview_desc': 'Ganito ang magiging hitsura ng iyong app.',
      'sample_button': 'Halimbawang Pindutan',
      'display_mode': 'Display Mode',
      'dark_mode': 'Dark Mode',
      'dark_mode_desc': 'Mas maginhawa sa mata kapag madilim.',
      'accent_color': 'Kulay ng App',

      // Sign Up Additions
      'create_your_account': 'Gumawa ng Iyong Account',
      'full_name': 'Buong Pangalan',
      'confirm_password': 'Kumpirmahin ang Password',
      'min_6_chars': 'Kulang sa 6 na letra',
      'mismatch': 'Hindi magkapareho',
      'agree_to_privacy': 'Dapat kang sumang-ayon sa Data Privacy Policy.',
      'read_understood': 'Nalaman at naunawaan ko ang ',
      'data_privacy_policy': 'Data Privacy Policy',
      'consent_processing':
          ' at sumasang-ayon sa pagproseso ng aking data ayon sa DPA of 2012. ',
      'learn_more': 'Alamin ang iba pa',
      'sign_up': 'Mag-Sign Up',
      'already_have_account_login': 'May account na? Mag-Log In',

      // Password Recovery & Google Auth
      'err_pass_min_6': 'Ang password ay dapat may hindi bababa sa 6 na letra.',
      'err_pass_mismatch': 'Hindi magkapareho ang password.',
      'success_app_password': 'Matagumpay na nai-set ang App Password!',
      'error_msg': 'Error: {message}',
      'secure_account': 'I-secure ang iyong Account',
      'google_password_desc':
          'Dahil nag-sign in ka gamit ang Google, mangyaring mag-set ng backup na password. Papayagan ka nitong mag-log in gamit ang email at mag-recover ng password sa hinaharap.',
      'create_password_hint': 'Gumawa ng Password',
      'save_continue': 'I-save at Magpatuloy',
      'forgot_password_title': 'Nakalimutan ang Password',
      'forgot_password_desc':
          'Ilagay ang iyong Email Address para ma-reset ang password.',
      'invalid_email_format': 'Ilagay ang tamang format ng email',
      'reset_password_btn': 'I-reset ang Password',
      'enter_otp': 'Ilagay ang OTP',
      'enter_otp_desc':
          'Ilagay ang OTP na ipinadala sa iyong rehistradong Email Address.',
      'verify_code': 'I-verify ang Code',
      'no_otp_yet': "Wala pa ring OTP? ",
      'resend_otp': 'Ipadala Ulit',
      'password_reset_title': 'Password Reset',
      'password_reset_success_desc':
          'Matagumpay na na-reset ang iyong password. I-click ang kumpirmahin para maglagay ng bagong password.',
      'confirm_btn': 'Kumpirmahin',
      'set_new_password': 'Gumawa ng Bagong Password',
      'set_new_password_desc':
          'Gumawa ng bagong password. Siguraduhing iba ito sa luma para mas ligtas.',
      'enter_new_password': 'Ilagay ang Bagong Password',
      'reenter_password': 'Ilagay ulit ang Password',
      'successful_title': 'Matagumpay',
      'successful_reset_desc':
          'Binabati kita! Matagumpay nang na-update ang iyong password.\nI-click ang magpatuloy para mag-Log In.',
      'continue_btn': 'Magpatuloy',

      // Core & Dashboard
      'trigger': 'Trigger',
      'lens': 'Lens',
      'hi': 'Kamusta',
      'cumulative_risk': 'NAIPON NA ACID',
      'hr_mn_sec': 'ORAS  MIN  SEK',
      'stomach_empty': 'Wala nang laman',
      'digesting': 'Kasalukuyang tinutunaw: {drink}',
      'queue_count': '(may {count} pang nakapila)',
      'target_strict': 'LIMIT: MAHIGPIT (<= 0.0)',
      'cap': 'LIMIT: {limit} POINTS',
      'coffee_allowance':
          'May natitira ka pang acid allowance na katumbas ng {cups} baso ng kape ngayong araw.',
      'scans': 'Na-scan',
      'consumed': 'Nainom',
      'symptoms': 'Mga Sintomas',
      'scan_sachet': 'Mag-scan ng sachet',
      'recent_scans': 'Mga Huling Na-scan',
      'view_all': 'Tingnan lahat',
      'no_recent_scans': 'Wala pang na-scan kamakailan.',
      'consumed_on': 'Nainom noong {date}',
      'offline_warning':
          'Walang internet. Gumagana ang Scanner at Pantry, pero nagpapahinga muna si Tummy Buddy.',
      'tooltip_daily_limit':
          'Ito ang iyong personal na limitasyon sa acid para sa araw na ito bago ka makaranas ng sintomas.',
      'tooltip_cumulative':
          'Ito ang kabuuang dami ng acid na kasalukuyang tinutunaw ng iyong tiyan. Kusang bababa ito sa loob ng 6 na oras.',

      // Notifications & Tips (NEWLY MAPPED TO TAGALOG)
      'updates_tips': 'Mga Update at Payo',
      'no_new_notifications': 'Walang bagong notification.',
      'quick_health_tip': 'Pangkalusugang Payo',
      'stress_penalty_active': 'Aktibo ang Stress Penalty',
      'stress_penalty_desc':
          'Pansamantalang ibinaba ng 15% ang iyong acid tolerance para protektahan ang tiyan mo.',
      'threshold_warning': 'Babala sa Limitasyon',
      'threshold_warning_desc':
          'Nasa {percent}% ka na ng iyong limit. Tubig muna ang inumin!',
      'ready_for_drink': 'Handa na bang uminom?',
      'scan_prompt_desc':
          'I-scan ang sachet para suriin ang acid level bago inumin.',
      'test_push': 'Test Push',

      // GERD Facts (TAGALOG)
      'tip_0':
          "Ang pagtulog nang nakatagilid sa kaliwa ay nakakaiwas sa pag-akyat ng asido.",
      'tip_1':
          "Ang pagnguya ng sugar-free gum ay nagpaparami ng laway na pumipigil sa asido.",
      'tip_2':
          "Ang paunti-unti at madalas na pagkain ay nakakabawas ng pressure sa tiyan.",
      'tip_3':
          "Huwag munang humiga sa loob ng 3 oras pagkatapos kumain o uminom.",
      'tip_4':
          "Ang masikip na damit sa baywang ay maaaring magtulak ng asido paitaas.",
      'tip_5':
          "Mas mainam ang dahan-dahang pag-inom ng tubig kaysa biglaan para hindi mabigla ang tiyan.",
      'tip_6':
          "Ang pag-angat ng ulunan ng higaan ng 6-8 pulgada ay nakakaiwas sa reflux sa gabi.",
      'tip_7':
          "Ang stress ay nagpapataas ng pagiging sensitibo ng tiyan kahit sa kaunting asido.",
      'tip_8':
          "Maghintay ng 30 minuto pagkatapos kumain bago mag-ehersisyo para iwas acid splash.",
      'tip_9':
          "Ang saging at melon ay may mababang asido na nakakapagpakalma ng tiyan.",
      'tip_10': "Ang oatmeal ay maganda sa paghigop ng sobrang asido sa tiyan.",
      'tip_11':
          "Ang paninigarilyo ay nagpapahina sa valve na pumipigil sa asido ng tiyan.",
      'tip_12':
          "Ang mga carbonated drinks ay nagpapataas ng pressure sa tiyan at nagdudulot ng pagdighay.",
      'tip_13':
          "Ang aloe vera juice (walang asukal) ay nakakatulong magpakalma ng lalamunan.",
      'tip_14':
          "Ang salabat (ginger tea) ay natural na nakakatulong sa panunaw.",
      'tip_15':
          "Ang pagkain nang late sa gabi ay pangunahing sanhi ng pangangasim sa umaga.",
      'tip_16':
          "Ang labis na timbang ay nagbibigay ng pressure sa tiyan kaya umaakyat ang asido.",
      'tip_17':
          "Maaaring magpalala ng reflux ang peppermint dahil nire-relax nito ang valve ng tiyan. Mag-ingat!",
      'tip_18':
          "Ang pag-inom ng maligamgam na tubig sa umaga ay nakakabuti sa panunaw.",
      'tip_19':
          "Hindi lang heartburn ang sintomas ng reflux—pwede rin ang ubo at makating lalamunan.",

      // Profile & Settings
      'tummy_friend': 'Kaibigan ng Tiyan',
      'no_email_connected': 'Walang nakakonektang email',
      'total_scans': 'Kabuuan Na-scan',
      'safe_drinks': 'Ligtas Inumin',
      'triggers': 'Mga Triggers',
      'medical_demographics': 'Medical Demographics',
      'clinical_status': 'Clinical Status',
      'preventative': 'Preventative',
      'age_group': 'Edad',
      'primary_goal': 'Pangunahing Layunin',
      'track_limit': 'Bantayan ang aking limit',
      'todays_tolerance': 'TOLERANCE MO NGAYON',
      'highly_sensitive': 'Masyadong Sensitibo',
      'highly_sensitive_desc':
          'Kasalukuyang napakasensitibo ng tiyan mo dahil sa stress o nakaraang sintomas. Tubig muna.',
      'slightly_sensitive': 'Medyo Sensitibo',
      'slightly_sensitive_desc':
          'Medyo mababa ang acid tolerance mo ngayon. Piliin ang mga mild na inumin.',
      'optimal_tolerance': 'Nasa Normal',
      'optimal_tolerance_desc':
          'Nasa normal at maayos na kondisyon ang tiyan mo ngayon.',
      'standard_baseline': 'Standard Baseline:',
      'your_active_limit': 'Active Limit Mo:',
      'coffee_cups': 'baso ng kape',
      'verified_personal_triggers': 'Mga Kumpirmadong Triggers Mo',
      'your_specific_triggers': 'Mga Partikular na Trigger Mo',
      'no_recent_symptoms': 'Walang nai-log na sintomas',
      'no_verified_triggers':
          'Wala pang kumpirmadong trigger. Lalabas lang ito kapag napatunayan ng app na nagdulot ito ng sintomas sa iyo.',
      'frequent_symptoms': 'Madalas na Sintomas',
      'no_symptoms_logged': 'Wala kang nilolog na sintomas. Ipagpatuloy yan!',
      'recalibrate_phase': 'I-recalibrate',
      'logged_times': 'Naitala mo ang "{name}" ng {count} na beses.',
      'settings': 'Mga Setting',
      'account': 'Account',
      'edit_profile': 'I-edit ang Profile at Avatar',
      'pro_scanner_prefs': 'Pro Scanner Preferences',
      'batch_scan_mode': 'Batch Scanning Mode',
      'batch_scan_mode_desc':
          'Mag-scan nang tuloy-tuloy nang hindi bumabalik sa menu.',
      'strict_risk_filter': 'Mahigpit na Risk Filter',
      'strict_risk_filter_desc':
          'Ituturing na Delikado (Red) ang mga inuming Medyo Delikado (Yellow).',
      'haptic_feedback': 'Vibration Feedback',
      'haptic_feedback_desc':
          'Magba-vibrate ang phone kapag successful ang scan at alerts.',
      'auto_flashlight': 'Auto-Flashlight',
      'auto_flashlight_desc':
          'Kusang bubukas ang flashlight pag-open ng scanner.',
      'security_legal': 'Seguridad at Legal',
      'medical_privacy_hub': 'Medical Privacy & Data Hub',
      'info_support': 'Impormasyon & Tulong',
      'log_out': 'Mag-Log Out',
      'log_out_q': 'Mag-Log Out?',
      'log_out_desc':
          'Sigurado ka bang gusto mong mag-log out sa iyong account?',
      'cancel': 'Kanselahin',

      // Avatar & Profile Edits
      'update_profile_pic': 'Palitan ang Profile Picture',
      'take_photo': 'Kumuha ng Litrato',
      'choose_gallery': 'Pumili sa Gallery',
      'choose_preset_avatar': 'O Pumili ng Preset Avatar',
      'avatar_updated': 'Nai-update na ang Avatar!',
      'update_failed': 'Pabigong i-update',
      'confirm_name_change': 'Kumpirmahin ang Pagpalit ng Pangalan',
      'confirm_name_desc':
          "Sigurado ka bang gusto mong palitan ang pangalan mo at gawing '{name}'?",
      'save_changes': 'I-save',
      'name_updated': 'Matagumpay na pinalitan ang pangalan!',
      'send_reset_email': 'Ipadala ang Reset Email?',
      'send_reset_desc': 'Magpapadala kami ng password reset link sa:',
      'send_email': 'Ipadala ang Email',
      'reset_link_sent': 'Ligtas na naipadala ang link sa {email}',
      'account_profile': 'Account Profile',
      'display_name': 'Pangalan',
      'registered_email': 'Rehistradong Email',
      'no_email_associated': 'Walang email na nakakonekta',
      'send_password_reset': 'Magpadala ng Password Reset Email',

      // Privacy Hub & Export
      'medical_data_hub_title': 'Medical Data &\nPrivacy Hub',
      'storage_policy': 'Patakaran sa Data',
      'cloud_sync': 'Cloud Sync & Backup',
      'cloud_sync_desc':
          'I-save sa cloud para ma-access mo kahit saang device. Kung naka-off ito, sa teleponong ito lang nakatago ang iyong data.',
      'anonymous_analytics': 'Anonymous Analytics',
      'anonymous_analytics_desc':
          'Tulungan kaming pagandahin ang TriggerLens. Walang personal na impormasyon ang kukunin.',
      'data_portability': 'Data Portability (R.A. 10173)',
      'request_data_export': 'I-download ang Data Ko',
      'request_data_export_desc':
          'Kumuha ng CSV na kopya ng iyong buong history.',
      'danger_zone': 'Danger Zone',
      'erase_local_logs': 'Burahin ang Data sa Teleponong Ito',
      'erase_local_logs_desc':
          'Buburahin ang lahat ng scan history sa teleponong ito lamang.',
      'erase_account': 'Burahin ang Account & Cloud Data',
      'erase_account_desc':
          'Permanenteng buburahin ang iyong account at lahat ng nakatago sa cloud.',
      'disable_cloud_backup_q': 'Huwag nang i-save sa Cloud?',
      'disable_cloud_desc':
          'Kung i-o-off mo ang Cloud Sync, sa teleponong ito na lang mase-save ang data mo. Kung ma-uninstall mo ang app o lumipat ka ng telepono, tuluyang mawawala ang lahat ng data mo.\n\nSigurado ka ba?',
      'disable_sync': 'I-off ang Sync',
      'export_failed': 'Pabigo ang export',
      'erase_local_logs_q': 'Burahin ang Data sa Telepono?',
      'erase_local_desc':
          'Agad na buburahin nito ang lahat ng food scans mo sa teleponong ito. Hindi ka mallo-log out.\n\nHindi na ito maibabalik.',
      'local_data_erased': 'Nabura na ang Data sa Device na ito.',
      'erase_local_data': 'Burahin ang Data',
      'delete_account_q': 'Burahin ang Account?',
      'delete_account_desc':
          'Nuclear option ito. Buburahin namin ang lahat ng data mo sa telepono, sa cloud, at isasara nang tuluyan ang account mo.\n\nSiguradong-sigurado ka na ba?',
      'security_requirement_delete':
          'Security Requirement: Mag-log out at mag-log in muna bago burahin ang account.',
      'permanently_delete': 'PERMANENTENG BURAHIN',
      'information': 'Impormasyon',
      'about_triggerlens': 'Tungkol sa TriggerLens',
      'version_desc': 'Sistema na kusang nagsusuri ng ingredients.',
      'help_support': 'Tulong at Suporta',
      'how_to_use_scanner': 'Paano gamitin ang Scanner',
      'how_to_use_scanner_desc': 'Itapat nang maayos sa sachet ang camera.',
      'legal_safety': 'Legal at Kaligtasan',
      'medical_disclaimer': 'Medical Disclaimer',
      'medical_disclaimer_desc': 'Hindi ito kapalit ng payo ng doktor.',
      'csv_date_scanned': 'Petsa Na-scan',
      'csv_product_name': 'Pangalan ng Inumin',
      'csv_risk_level': 'Antas ng Panganib',
      'csv_acid_score': 'Acid Score',
      'csv_symptoms_logged': 'Naitalang Sintomas',
      'csv_none': 'Wala',
      'csv_export_title': 'Kopya ng aking TriggerLens Data',

      // Privacy Policy
      'privacy_policy_title': 'Paunawa sa Data Privacy',
      'privacy_policy_content':
          'Nangangako ang TriggerLens na protektahan ang iyong medikal at personal na data alinsunod sa Data Privacy Act of 2012 (R.A. 10173).\n\n1. Pagkolekta ng Data\nKumokolekta kami ng impormasyon (edad, clinical status) at mga naitalang sintomas upang i-customize ang iyong acid reflux limit. Ginagamit lang ito para buuin ang iyong dynamic limit.\n\n2. Pag-scan ng Imahe\nAng mga larawang kuha ng OCR scanner ay ligtas na pinoproseso sa Google ML Kit. Hindi namin itinatago o ibinabahagi ang mga larawan ng iyong paligid o pagkain.\n\n3. Cloud Sync\nKung naka-enable, ligtas na naka-sync ang iyong data sa iyong personal cloud account. Ikaw ang may-ari ng iyong data at maaari mo itong burahin anumang oras gamit ang Medical Privacy Hub.\n\n4. Analytics\nMaaari kaming kumuha ng anonymous usage data (tulad ng bilis ng pag-scan) upang mapabuti ang aming sistema. Walang personal na impormasyong ibabahagi sa iba.',
      'i_understand_btn': 'Naiintindihan Ko',

      // Scanner & Diagnostics
      'analyzing_env': 'Sinusuri ang paligid...',
      'move_closer': 'Ilapit ang camera sa mga ingredients.',
      'text_distorted': 'Hindi mabasa. Pakiunat ang lukot na sachet.',
      'glare_detected': 'Masyadong nakakasilaw. Ilayo nang konti sa ilaw.',
      'scanning_text': 'Binabasa ang mga salita...',
      'ingredients_detected': 'Nakita na ang ingredients! Naglo-lock on...',
      'need_diff_approach': 'Nahihirapan ang scanner?',
      'shiny_curved_desc':
          'Mahirap basahin ang makikintab o kurbadang sachet. Gusto mo bang subukan ang iba pang paraan?',
      'manual_shutter': 'Pindutin ang Camera',
      'take_photo_desc': 'Kumuha ng litrato at i-crop ito nang manu-mano',
      'type_ingredients': 'I-type ang Ingredients',
      'type_ingredients_desc': 'Manu-manong i-type ang nakasulat',
      'keep_trying_auto': 'Ipagpatuloy ang Auto-Scan',

      // Pantry, Results & Filters (NEWLY MAPPED)
      'filters': 'Mga Filter',
      'sort_newest': 'Pinakabago',
      'sort_oldest': 'Pinakaluma',
      'sort_highest_risk': 'Pinakadelikado',
      'sort_lowest_risk': 'Pinakaligtas',
      'sort_a_z': 'A-Z',
      'digestion_complete_title': 'Natunaw Na',
      'digestion_complete_body':
          'Anim na oras na simula nang inumin mo ang {name}. Ligtas na muli ang tiyan mo.',
      'acid_buffer_reminder': 'Pampakalma ng Tiyan',
      'acid_buffer_body':
          'Dahil ininom mo ang {name} nang walang laman ang tiyan, humigop ng paunti-unting tubig para maprotektahan ang sikmura.',
      'symptom_checkin_title': 'Kamusta ang tiyan mo?',
      'symptom_checkin_body':
          'Ano ang pakiramdam matapos inumin ang {name}? I-tap para i-log kung may masakit.',
      'item_consumed_logged': 'Nainom at nai-log na ang {name}!',
      'saved_to_pantry': 'Na-save sa Digital Pantry!',
      'name_this_drink': 'Pangalanan itong Inumin',
      'eg_nescafe': 'halimbawa, Nescafe 3-in-1',
      'save_name': 'I-save ang Pangalan',
      'unnamed': 'Walang Pangalan',
      'manual_entry': 'I-type Manu-mano',
      'type_ingredients_hint':
          'I-type ang ingredients, lagyan ng kuwit bawat isa...',
      'analyze': 'Suriin',

      // Symptoms
      'log_a_symptom': 'Mag-log ng Sintomas',
      'track_how_you_feel': 'Bantayan ang epekto sa tiyan mo',
      'log_clinical_symptom': 'Log Clinical Symptom',
      'log_symptom_desc':
          'Piliin ang pinaka-akmang naglalarawan sa nararamdaman mo ngayon. Nakakatulong ito para tumpak na malaman ng TriggerLens kung alin ang nakakasama sa iyo.',
      'what_symptoms': 'Anong sintomas ang nararanasan mo ngayon?',
      'severity_scale_q': 'Mula 1 hanggang 10, gaano katindi ang sakit?',
      'save_log': 'I-save ang Log',
      'save_biological_log': 'I-save ang Biological Log',
      'symp_heartburn': 'Heartburn / Pangangasim',
      'desc_heartburn': 'Mainit o mahapdi sa gitna ng dibdib',
      'symp_acid_regurgitation': 'Acid Regurgitation',
      'desc_acid_regurgitation': 'Maaskad na likido na umaakyat sa lalamunan',
      'symp_dyspepsia': 'Dyspepsia / Empatso',
      'desc_dyspepsia': 'Mabigat, kumukulo, o masakit ang itaas na tiyan',
      'symp_globus_sensation': 'Globus Sensation',
      'desc_globus_sensation': 'Parang may nakabarang bukol sa lalamunan',
      'symp_nausea': 'Nausea / Pagduduwal',
      'desc_nausea': 'Pakiramdam na parang masusuka',
      'symp_excessive_burping': 'Madalas na Pag-dighay',
      'desc_excessive_burping': 'Hangin na sapilitang umaakyat palabas',
      'symp_none': 'Wala',
      'desc_none': 'Okay ang pakiramdam ko!',
      'symp_bloating': 'Paglobo ng Tiyan',
      'symp_burping': 'Pag-dighay',
      'symp_cramps': 'Paghilab (Cramps)',
      'symp_chest_pain': 'Pananakit ng Dibdib',
      'symp_acidic_taste': 'Maaskad na Lasa',
      'symp_sore_throat': 'Makating Lalamunan',
      'symp_dry_cough': 'Tuyong Ubo',

      // Veridcts & UI
      'high_danger': 'Lubhang Delikado',
      'moderate_risk': 'Medyo Delikado',
      'safe_to_consume': 'Ligtas Inumin',
      'scan_again': 'Mag-Scan Uli',
      'save_to_pantry_btn': 'I-save sa Pantry',
      'consume_now': 'Inumin Ngayon',
      'auto_scan_mode': 'Auto-Scan Mode',
      'manual_entry_analysis': 'Pagsusuri ng Tinype na Teksto',
      'extracting_text': 'Kinukuha ang teksto via Google ML Kit...',
      'category_label': 'Uri:',
      'acid_impact_verdict': 'Epekto sa Acid Threshold',
      'acid_points': 'Acid Points',
      'dashboard_impact': 'Epekto sa Dashboard',
      'percent_daily_cap': '{percent}% ng Daily Limit mo',
      'potential_clinical_irritants': 'Mga Posibleng Makasama',
      'raw_ocr_data': 'Raw OCR System Data',
      'tap_to_edit_ocr':
          'I-tap para i-edit ang maling basa. Kailangan mong pindutin ang Recalibrate para ma-update ang score.',
      'no_text_provided': 'Walang tekstong inilagay.',
      'recalibrating': 'Nire-recalibrate...',
      'recalibrate_analysis': 'I-recalibrate ang Pagsusuri',
      'analysis_recalibrated': 'Matagumpay na na-recalibrate ang pagsusuri!',
      'pantry_item_recalibrated': 'Matagumpay na na-recalibrate ang inumin!',
      'log_symptom_btn': 'I-log ang Sintomas',
      'first_aid_coach': 'First Aid Coach',
      'gallery': 'Gallery',
      'type_ingredients_manually': 'I-type ang Ingredients Manu-mano',
      'how_it_works': 'Paano ito gumagana',
      'how_it_works_desc':
          'Itapat lang ang camera sa sachet. Kusang hahanapin at susuriin ng scanner ang mga ingredients para sa pagsusuri. Hindi mo kailangang pumindot maliban na lang kung magkaproblema ang scanner.',

      // Digital Pantry
      'digital_pantry': 'Digital Pantry',
      'search_inventory': 'Hanapin sa pantry mo...',
      'all': 'Lahat',
      'favorites': 'Paborito',
      'safe': 'Ligtas',
      'med': 'Katamtaman',
      'high': 'Delikado',
      'pantry_empty_title': 'Walang laman ang iyong Pantry!',
      'pantry_empty_desc':
          'I-tap ang scanner sa ibaba para suriin at i-save ang una mong inumin. Dito mapupunta ang mga ligtas mong paborito pati na rin ang mga delikadong triggers.',
      'logged_on': 'Na-log noong {date}',
      'historical_impact': 'Epekto Ayon sa Kasaysayan',
      'portion_label': 'Dami: {count} {measure}',
      'consumed_empty_stomach': 'Ininom nang Walang Laman ang Tiyan',
      'consumed_with_food': 'Ininom Habang Kumakain',
      'clinical_symptoms': 'Mga Klinikal na Sintomas',
      'pantry_saved_info':
          "Naka-save ang item na this sa iyong pantry. I-tap ang 'Inumin' sa ibaba kapag iinumin mo na ito para simulan ang timer at mabuksan ang symptom tracking.",
      'delete': 'Burahin',
      'consume_btn': 'Inumin',
      'drink_again': 'Inumin Uli',
      'saved_only': 'NAKA-SAVE LANG',
      'exceeds_daily_cap': '⚠️ Lampas na sa Acid Limit Mo',

      // Drink Categories
      'herbal_tea': 'Herbal Tea',
      'liquid_concentrate': 'Liquid Concentrate',
      'heavy_powder': 'Mabigat na Powder',
      'general_beverage': 'Pangkaraniwang Inumin',

      // AI Coach
      'greeting_general':
          'Kamusta {name}! Ako si Tummy Buddy ✨ Paano kita matutulungan ngayon?',
      'greeting_scanner':
          'Kamusta {name}! Nakita kong nakakaranas ka ng {symptom} pagkatapos mong inumin ang {product}. Gusto mo ba ng mga simpleng payo para gumaan ang pakiramdam mo ngayon? 🩹',
      'greeting_insights':
          'Kamusta {name}! Tinitingnan ko ang iyong mga nakaraang insights. Mag-isip tayo ng paraan para mapanatiling ligtas ang acid level mo araw-araw! 📊',
      'tummy_buddy': 'Tummy Buddy',
      'insight_analyst': 'Insight Analyst',
      'chat_auto_delete_notice':
          'Kusang nabubura ang mga chat pagkalipas ng 14 araw. I-long press ang isang mensahe para burahin ito agad.',
      'chat_hint': 'Sabihin kay Tummy Buddy ang nararamdaman mo...',
      'tummy_buddy_typing': 'Nagta-type si Tummy Buddy...',
      'clear_chat_q': 'Burahin ang Chat?',
      'clear_chat_desc':
          'Permanenteng buburahin nito ang memorya ng ating pag-uusap mula sa teleponong ito.',
      'delete_message_q': 'Burahin ang Mensahe?',
      'delete_message_desc':
          'Sigurado ka bang gusto mong burahin ang partikular na mensaheng ito?',
      'error_no_internet':
          'Naku! Kailangan ko ng internet para makapag-isip. Paki-check ang iyong Wi-Fi o data! 🫧',
      'error_medical_emergency':
          '⚠️ Tunog emergency ito. Hindi ako doktor. Mangyaring itigil muna ang paggamit sa app at humingi agad ng tulong medikal, pumunta sa pinakamalapit na ospital, o tumawag sa emergency hotline.',
      'error_connection_hiccup':
          'Nawala ang aking koneksyon nang saglit! Pindutin ulit ang send at tutulungan kita agad. 🧸',
      'error_server_unreachable':
          'Nahihirapan si Tummy Buddy na maabot ang server ngayon. Uminom ka muna ng unti-unting tubig, at subukang ipadala ulit ang mensahe mo maya-maya! 🍵✨',

      // Onboarding
      'skip': 'Laktawan',
      'onboard_q1_title': 'Ano ang nagdala sa iyo sa TriggerLens ngayon?',
      'diagnosed_gerd': 'May Diagnosed GERD',
      'diagnosed_gerd_desc':
          'Na-diagnose na ako ng doktor. Gagamit kami ng mahigpit at protektadong baseline.',
      'occasional_reflux': 'Paminsan-minsang Reflux',
      'occasional_reflux_desc':
          'Nakakaranas ako ng pangangasim paminsan-minsan. Tutulungan ka naming hanapin ang iyong pattern.',
      'preventative_desc':
          'Gusto kong bantayan ang kalusugan ng tiyan ko at iwasan ang problema bago pa man magsimula.',
      'onboard_q2_title': 'Ano ang iyong edad?',
      'under_18': 'Bata pa sa 18',
      'under_18_desc':
          'Mataas ang resistensya ng mga bata, pero mahalagang magsimula ng ligtas na gawi.',
      'age_18_25': '18-25',
      'age_18_25_desc':
          'Pinakamataas na metabolismo. Maglalagay kami ng balanse at karaniwang acid baseline.',
      'age_26_45': '26-45',
      'age_26_45_desc':
          'Nagsisimula nang magbago ang metabolismo. I-aadjust namin ang limitasyon mo para bumagay.',
      'age_46_older': '46 pataas',
      'age_46_older_desc':
          'Kailangan ng mas mahigpit at mas ligtas na limitasyon. Sagot ka namin.',
      'onboard_q3_title': 'Gaano ka kadalas nakakaranas ng pananakit?',
      'almost_every_day': 'Halos araw-araw',
      'almost_every_day_desc':
          'Kailangan mo ng mahigpit na recovery routine. Babantayan ka namin nang mabuti.',
      'few_times_a_week': 'Ilang beses sa isang linggo',
      'few_times_a_week_desc':
          'Katamtamang iritasyon. Tutulungan ka naming hanapin ang mga sanhi nito.',
      'rarely': 'Bihira',
      'rarely_desc':
          'Paminsan-minsang pananakit. Tututok tayo sa paghahanap sa mga pambihirang triggers mo.',
      'onboard_q4_title': 'Ano ang pangunahing layunin mo?',
      'discover_hidden_triggers': 'Hanapin ang mga nakatagong trigger',
      'discover_hidden_triggers_desc':
          'Gagamit tayo ng OCR para hanapin ang maaasim na kemikal bago mo pa ito inumin.',
      'prevent_nighttime_reflux': 'Iwasan ang reflux sa gabi',
      'prevent_nighttime_reflux_desc':
          'Magpopokus tayo sa oras ng pag-inom mo sa gabi at sa bigat ng iyong tiyan bago matulog.',
      'track_limit_desc':
          'Bibigyan ka namin ng sinusubaybayang Acid Point allowance araw-araw para maging balanse ang tiyan mo.',
      'calibrate_engine': 'I-calibrate ang Engine',
      'next': 'Susunod',
      'are_you_sure': 'Sigurado ka ba?',
      'skip_warning_desc':
          'Kung lalaktawan mo ito, bibigyan ka lang ng pangkaraniwang acid limit. Para sa mas ligtas at personal na proteksyon, inirerekumenda naming sagutin mo ito.',
      'skip_anyway': 'Laktawan Pa Rin',
      'continue_quiz': 'Ipagpatuloy ang Quiz',
      'ready_to_commit':
          'Handa ka na bang panindigan ang mas malusog na pamumuhay?',
      'commit_desc':
          'Handa na ang iyong personal na biological profile. Idiin ang iyong hinlalaki sa ibaba upang pagtibayin ang iyong desisyon at simulan ang engine.',
      'press_hold_commit': 'PINDUTIN AT IDIIN PARA MAGSIMULA',

      // Path Screen & Assessment
      'choose_your_path': 'Piliin ang Iyong\nDaan',
      'path_diagnosed_title': 'Mayroon Akong Diagnosis',
      'path_diagnosed_desc':
          'Kumpirmado ng doktor na mayroon akong GERD o acid reflux.',
      'path_screen_title': 'Gusto kong suriin ang sarili ko',
      'path_screen_desc':
          'Gusto kong malaman ang reaksyon ko sa mga inumin at tukuyin kung ano ang nakakasama sa akin.',
      'gerd_clinical_assessment': 'Klinikal na Pagsusuri',
      'gerd_assessment_desc':
          'Para maging ligtas ang iyong baseline, kailangan naming malaman ang kasalukuyang lala ng iyong kondisyon.',
      'gerd_q1':
          '1. Gaano kadalas kang nagigising sa gabi dahil sa pangangasim o acid reflux?',
      'gerd_q2':
          '2. Gaano kadalas kang umaasa sa antacids o mga iniresetang gamot (PPI)?',
      'gerd_q3':
          '3. Nakakaranas ka ba ng dysphagia (hirap o sakit sa paglunok)?',
      'opt_never': 'Hindi',
      'opt_sometimes': 'Minsan',
      'opt_often': 'Madalas',
      'opt_rarely': 'Bihira / Wala',
      'opt_otc_occ': 'Paminsan-minsang OTC',
      'opt_daily_rx': 'Araw-araw / Reseta',
      'opt_no': 'Wala',
      'opt_mild': 'Magaan / Minsan',
      'opt_severe': 'Malala / Madalas',
      'generate_profile': 'Buuin ang Profile',
      'health_assessment': 'Pagsusuri ng Kalusugan',
      'gerdq_assessment': 'GerdQ Assessment',
      'gerdq_desc':
          'Pakisagot kung gaano mo kadalas naramdaman ang mga sumusunod na sintomas sa nakalipas na 7 araw.',
      '0_days': '0 Araw',
      '1_day': '1 Araw',
      '2_3_days': '2-3 Araw',
      '3_days': '3 Araw',
      '4_7_days': '4-7 Araw',
      '7_days': '7 Araw',
      '14_days': '14 Araw',
      '30_days': '30 Araw',
      'answer_all_questions':
          'Pakisagot ang lahat ng 6 na katanungan upang magpatuloy.',
      'calc_risk_profile': 'Kalkulahin ang Aking Risk Profile',
      'gerdq_q1':
          '1. Gaano kadalas ka nakaramdam ng pag-init o paghapdi sa gitna ng iyong dibdib (heartburn)?',
      'gerdq_q2':
          '2. Gaano kadalas umakyat ang likido o pagkain mula sa tiyan patungo sa iyong lalamunan o bibig (regurgitation)?',
      'gerdq_q3':
          '3. Gaano kadalas sumakit ang bandang itaas ng iyong sikmura?',
      'gerdq_q4': '4. Gaano kadalas kang nakaramdam ng pagkahilo o pagduduwal?',
      'gerdq_q5':
          '5. Gaano kadalas kang nahirapang makatulog nang maayos dahil sa heartburn o pangangasim?',
      'gerdq_q6':
          '6. Gaano kadalas kang uminom ng karagdagang gamot para sa pangangasim, bukod pa sa inireseta ng doktor mo (kung mayroon man)?',

      // Journal Screen
      'daily_checkin': 'Araw-araw na Check-in',
      'how_tummy_feeling': 'Kamusta ang tiyan mo ngayon?',
      'category_digestion': 'Panunaw',
      'category_pain_discomfort': 'Pananakit at Diskomportable',
      'category_throat_mouth': 'Lalamunan at Bibig',
      'overall_discomfort': 'Kabuuang Pananakit',
      'none': 'Wala',
      'severe': 'Matindi',
      'save_checkin': 'I-save ang Check-in',
      'daily_symptoms_logged':
          'Matagumpay na nai-save ang iyong sintomas ngayong araw! ✨',

      // Insights Additions
      'insights': 'Insights',
      'profile_label': 'Profile:',
      '7_day_clinical_trends': '7-Araw na Klinikal na Trends',
      'all_time_lifestyle_patterns': 'Pangkalahatang Lifestyle Patterns',
      'most_vulnerable': 'Pinaka-Sensitibong Oras',
      'empty_stomach_label': 'Walang Laman na Tiyan',
      'flare_ups_count': '{count} na Pag-atake',
      'primary_clinical_symptom': 'Pangunahing Sintomas',
      'symptom_logs_count': '{name} ({count} beses)',
      'not_enough_data_triggers':
          'Wala pang sapat na data para matukoy ang kemikal na nakakasama sa iyo.',
      'ingredients_repeatedly_appear':
          'Ang mga sangkap na ito ay madalas lumitaw bago ka makaramdam ng sintomas:',
      'incidents_count': '{count} na Insidente',
      'session_tracker': 'Session Tracker',
      'currently_digesting': 'Kasalukuyang Tinutunaw: {drink}',
      'queue_position': 'Item {current} mula sa {total}',
      'history_log': 'Kasaysayan',
      'entries_count': '{count} na nakatala',
      'no_drinks_logged': 'Walang naitalang inumin sa panahong ito.',
      'see_more': 'Tingnan Pa',
      'export_clinical_report': 'I-export ang Clinical Report',
      'download_pdf': 'I-download ang PDF',
      'save_copy_device': 'I-save ang kopya sa iyong device',
      'print_pdf': 'I-print ang PDF',
      'send_wireless_printer': 'Ipadala direkta sa wireless printer',
      'share_pdf': 'I-share ang PDF',
      'send_via_social': 'Ipadala via Email, Viber, o Messenger',
      'downloaded_to_documents': 'Na-download sa Documents: {file}',
      'no_insights_yet': 'Wala pang Insights',
      'no_insights_desc':
          'Lalabas dito ang iyong biological trends at interactive charts kapag nagsimula ka nang mag-scan mula sa iyong Pantry.\n\nI-tap ang Scanner sa ibaba para magsimula!',
      'cap_label': 'LIMIT',
      'today': 'Ngayon',
      'todays_breakdown': "Kabuuan Ngayong Araw",
      'no_drinks_this_day': 'Walang ininom sa araw na ito.',
      'logged_symptom_list': 'Sintomas: {symptoms}',
      'not_enough_data': 'Kulang sa Data',

      // Consumption Modal additions
      'consuming_item': 'Iinumin: {name}',
      'quick_context': 'Kailangang impormasyon para sa algorithm:',
      'portion_size': 'Dami ng Inumin',
      'stomach_state': 'Lagay ng Tiyan',
      'empty_stomach': 'Walang Laman ang Tiyan',
      'empty_stomach_desc': 'Kagigising lang o nakapahinga ang tiyan',
      'just_ate': 'Kakakain Lang / Busog',
      'just_ate_desc': 'Ininom kasabay o pagkatapos kumain',
      'preparation': 'Paghahanda',
      'standard_mix': 'Standard na Timpla',
      'standard_mix_desc': 'Hinanda ayon sa normal na sukat',
      'diluted': 'Pinarami / Malabnaw',
      'diluted_desc': 'Dinagdagan ng mas maraming tubig o gatas',
      'save_and_consume': 'I-save & Inumin',
      'measure_sachet': 'Sachet',
      'measure_tea_bag': 'Tea Bag',
      'measure_tablespoon': 'Kutsara (Tablespoon)',
      'measure_teaspoon': 'Kutsarita (Teaspoon)',
      'measure_drop_dash': 'Patak (Drop/Dash)',

      // Risk Translator
      'humanized_score_low':
          'Napakababa ng acid load ng inuming ito ({score} Points). Halos katumbas lang ito ng pag-inom ng alkaline water o mild na herbal tea.',
      'humanized_score_med':
          'Ang inuming ito ay may {score} Acid Points. Bilang gabay, ang 1 point ay halos katumbas ng acid load ng isang karaniwang baso ng black coffee.',
      'humanized_score_high':
          'Mabigat ang acid load nito na umaabot sa {score} Acid Points. Katumbas ito ng pag-inom ng 2 hanggang 3 baso ng matapang na kape nang sabay-sabay.',
      'humanized_score_extreme':
          'BABALA: Sobrang taas ng acid load ({score} Points). Katumbas ito ng pag-inom ng matapang na energy drink o purong katas ng citrus. Mataas ang panganib na magka-reflux.',
      'impact_breach_fasting':
          'Kung iinumin mo ito, lalampas ka agad sa iyong mahigpit na fasting limit.',
      'impact_percentage':
          'Ang pag-inom ng daming ito ay uubos sa {percentage}% ng iyong {cap}-point na allowance ngayong araw.',
      'rec_plenty_room':
          'Malaki pa ang natitira sa iyong acid allowance ngayong araw. Ligtas mong maiinuman ang buong serving nito.',
      'rec_heavy_powder':
          'Mababa na ang allowance mo. Imbes na ubusin ang isang sachet, subukang gumamit ng 1-2 kutsarita lang at damihan ang tubig o gatas (oat milk).',
      'rec_liquid_concentrate':
          'Mababa na ang allowance mo. Para iwas-acid, gumamit lang ng ilang patak o isang kutsarita nito at haluan ng maraming yelo at tubig.',
      'rec_herbal_tea':
          'Mababa na ang allowance mo. Para hindi masyadong umasim, ibabad (steep) ang tea bag ng 1 minuto lamang o kaya\'y gawin itong cold-brew.',
      'rec_default':
          'Mababa na ang allowance mo. Inirerekumenda namin na kalahati lang ang inumin nito at sundan agad ng isang basong tubig.',

      // Calibration Screen
      'analyzing_reflux': 'Sinusuri ang dalas ng iyong reflux...',
      'calc_target_pral': 'Kinakalkula ang iyong target na Acid Score...',
      'applying_modifiers': 'Ibinabagay sa iyong edad...',
      'profile_ready': 'Handa na ang iyong profile!',
      'calibrating': 'Kina-calibrate',
      'reflux_pattern_mapped': 'Naitala na ang pattern',
      'target_pral_configured': 'Na-configure na ang Acid Score',
      'clinical_modifiers_applied': 'Nailapat na ang modifiers',
      'tailoring_triggerlens': 'Inaayos para sa iyong tiyan...',
    }
  };

  static String translate(String key, String languageCode,
      [Map<String, String>? params]) {
    String text = _localizedValues[languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
    if (params != null) {
      params.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }
}

class AppLocalizations extends InheritedWidget {
  final LanguageProvider languageProvider;

  const AppLocalizations({
    super.key,
    required this.languageProvider,
    required super.child,
  });

  static AppLocalizations of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocalizations>()!;
  }

  String loc(String key, [Map<String, String>? params]) {
    return LanguageDictionary.translate(
        key, languageProvider.currentLanguage, params);
  }

  @override
  bool updateShouldNotify(AppLocalizations oldWidget) {
    return languageProvider.currentLanguage !=
        oldWidget.languageProvider.currentLanguage;
  }
}
