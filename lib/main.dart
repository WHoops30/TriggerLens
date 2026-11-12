import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import 'firebase_options.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/scanner_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'utils/ui_helpers.dart';
import 'utils/app_localizations.dart';
import 'screens/digital_pantry_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/coach_screen.dart';
import 'models/user_profile.dart';

// ==========================================
// GLOBAL STATE: User Session Provider
// Ensures profile picture/name updates immediately reflect across the app
// ==========================================
class UserSessionProvider extends ChangeNotifier {
  final DatabaseService dbService;
  UserProfile? _profile;
  String? _avatarPath;

  UserSessionProvider(this.dbService);

  UserProfile? get profile => _profile;
  String? get avatarPath => _avatarPath;

  Future<void> loadProfile() async {
    _profile = await dbService.getUserProfile();

    // Fetch the local avatar synchronously for global use
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    _avatarPath = prefs.getString('local_avatar_$uid');

    notifyListeners();
  }

  void refreshSession() {
    loadProfile();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ==========================================
  // 0. SECURE API KEY INJECTION WITH DOUBLE FALLBACK
  // ==========================================
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("🔐 Environment Variables Loaded from root");
  } catch (e) {
    try {
      // Fallback for strict bundlers
      await dotenv.load(fileName: "assets/.env");
      debugPrint("🔐 Environment Variables Loaded from assets");
    } catch (e2) {
      debugPrint(
          "⚠️ WARNING: .env file not found. AI features will be locked.");
    }
  }

  // ==========================================
  // 1. MUST INITIALIZE FIREBASE FIRST
  // ThemeProvider relies on FirebaseAuth to fetch the user's custom colors
  // ==========================================
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("🔥 Firebase Initialized Successfully!");
  } catch (e) {
    debugPrint("⚠️ Firebase init failed: $e");
  }

  // ==========================================
  // 2. INITIALIZE PROVIDERS
  // ==========================================
  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider();

  await themeProvider.loadSettings();
  await languageProvider.loadLanguage();

  // ==========================================
  // 3. INITIALIZE AUXILIARY SERVICES & DATABASE
  // ==========================================
  try {
    await NotificationService().init();
    debugPrint("🔔 Notification Service Initialized Successfully!");
  } catch (e) {
    debugPrint("⚠️ Notification init failed: $e");
  }

  final dbService = DatabaseService();
  await dbService.initDB();

  // FIREWALL: Automatically purge data older than 14 days to keep app blazing fast
  await dbService.purgeOldData();
  await dbService.seedDefaultData();

  final userSessionProvider = UserSessionProvider(dbService);

  // ==========================================
  // 4. RUN APP (Routing delegated to RootStateDispatcher)
  // ==========================================
  runApp(MyApp(
    dbService: dbService,
    themeProvider: themeProvider,
    languageProvider: languageProvider,
    userSessionProvider: userSessionProvider,
  ));
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;
  final ThemeProvider themeProvider;
  final LanguageProvider languageProvider;
  final UserSessionProvider userSessionProvider;

  const MyApp({
    super.key,
    required this.dbService,
    required this.themeProvider,
    required this.languageProvider,
    required this.userSessionProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider.value(value: userSessionProvider),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, theme, lang, child) {
          return AppLocalizations(
            languageProvider: lang,
            child: MaterialApp(
              // FIXED: The ValueKey forces the entire app UI to instantly rebuild when language switches
              key: ValueKey(lang.currentLanguage),
              title: 'TriggerLens',
              debugShowCheckedModeBanner: false,
              themeMode: theme.themeMode,
              theme: theme.lightTheme,
              darkTheme: theme.darkTheme,
              home: RootStateDispatcher(dbService: dbService),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// ROOT STATE DISPATCHER (The Anti-Loop Engine)
// ==========================================
class RootStateDispatcher extends StatefulWidget {
  final DatabaseService dbService;

  const RootStateDispatcher({super.key, required this.dbService});

  @override
  State<RootStateDispatcher> createState() => _RootStateDispatcherState();
}

class _RootStateDispatcherState extends State<RootStateDispatcher> {
  @override
  void initState() {
    super.initState();
    // Load the profile into global state upon app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserSessionProvider>(context, listen: false).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show Splash Screen while checking Firebase state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoadingScreen();
        }

        // 1. If NO Firebase User exists -> Route to Welcome Screen
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return WelcomeScreen(dbService: widget.dbService);
        }

        // 2. Hook into the global UserSessionProvider instead of FutureBuilder
        // This allows instant routing updates when profile changes
        return Consumer<UserSessionProvider>(
          builder: (context, session, child) {
            final profile = session.profile;

            // If profile is null, it's either loading or doesn't exist yet
            if (profile == null) {
              // Quick silent check to avoid infinite loading if they genuinely have no profile
              widget.dbService.getUserProfile().then((p) {
                if (p == null && mounted) {
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              OnboardingScreen(dbService: widget.dbService)));
                }
              });
              return const _SplashLoadingScreen();
            }

            // 3. If profile exists AND isSetupComplete is true -> Route to Dashboard
            if (profile.isSetupComplete) {
              return MainLayoutScreen(dbService: widget.dbService);
            }
            // 4. Otherwise (No profile or did not finish setup) -> Route to Smart Onboarding
            else {
              return OnboardingScreen(dbService: widget.dbService);
            }
          },
        );
      },
    );
  }
}

// ==========================================
// SLEEK AUTO-LOGIN SPLASH SCREEN
// ==========================================
class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const TriggerLensLogo(
                size: 110, showText: true, isHorizontal: false),
            const SizedBox(height: 40),
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                  color: colors.primary, strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MAIN LAYOUT SCREEN (Dashboard Root)
// ==========================================
class MainLayoutScreen extends StatefulWidget {
  final DatabaseService dbService;
  final int initialIndex;

  const MainLayoutScreen({
    super.key,
    required this.dbService,
    this.initialIndex = 0,
  });

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  late int _currentIndex;
  bool _isOffline = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      if (mounted) {
        setState(() {
          _isOffline = results.contains(ConnectivityResult.none);
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<bool?> _showExitDialog() {
    final colors = AppColors.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Exit TriggerLens?",
          style: TextStyle(color: colors.textDark, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to exit the application?",
          style: TextStyle(color: colors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text("Cancel", style: TextStyle(color: colors.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.errorRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Exit App",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final List<Widget> screens = [
      DashboardScreen(dbService: widget.dbService),
      DigitalPantryScreen(dbService: widget.dbService),
      InsightsScreen(dbService: widget.dbService),
      CoachScreen(dbService: widget.dbService),
    ];

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _showExitDialog() ?? false;
        if (shouldPop) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            screens[_currentIndex],

            // OFFLINE BANNER ANIMATION
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              top: _isOffline ? 0 : -150,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  decoration: BoxDecoration(
                      color: Colors.orange.shade800,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 5))
                      ]),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(loc.loc('offline_warning'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
        // FIXED: The Scanner FAB is now completely persistent globally, only hiding when the keyboard is open to prevent UI blocking.
        floatingActionButton: isKeyboardOpen
            ? null
            : SizedBox(
                width: 70,
                height: 70,
                child: FloatingActionButton(
                  elevation: 5,
                  backgroundColor: colors.primaryDark,
                  shape: const CircleBorder(),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ScannerScreen(dbService: widget.dbService),
                    ),
                  ),
                  child: Image.asset('assets/images/barcode-scanner.png',
                      width: 32, color: Colors.white),
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: isKeyboardOpen
            ? null
            : Container(
                margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                decoration: BoxDecoration(
                  color: colors.cardColor,
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5)),
                  ],
                ),
                child: BottomAppBar(
                  color: Colors.transparent,
                  elevation: 0,
                  shape: const CircularNotchedRectangle(),
                  notchMargin: 12.0,
                  child: SizedBox(
                    height: 65,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem('assets/images/home.png', 0, colors),
                        _buildNavItem('assets/images/write.png', 1, colors),
                        const SizedBox(width: 45),
                        _buildNavItem('assets/images/bar-graph.png', 2, colors),
                        _buildNavItem('assets/images/message.png', 3, colors),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNavItem(String imagePath, int index, AppColors colors) {
    final isSelected = _currentIndex == index;

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? colors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Image.asset(
          imagePath,
          width: 24,
          color: isSelected ? Colors.white : colors.textDark,
        ),
      ),
      onPressed: () => setState(() => _currentIndex = index),
    );
  }
}
