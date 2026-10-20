import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';
import 'screens/scanner_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/path_screen.dart';
import 'utils/ui_helpers.dart';
import 'screens/digital_pantry_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService().init();
    debugPrint("🔔 Notification Service Initialized Successfully!");
  } catch (e) {
    debugPrint("⚠️ Notification init failed: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("🔥 Firebase Initialized Successfully!");
  } catch (e) {
    debugPrint("⚠️ Firebase init failed: $e");
  }

  final dbService = DatabaseService();
  await dbService.initDB();
  await dbService.seedDefaultData();

  final existingProfile = await dbService.getUserProfile();
  final currentUser = FirebaseAuth.instance.currentUser;

  Widget initialScreen;
  if (existingProfile == null) {
    initialScreen = OnboardingScreen(dbService: dbService);
  } else if (currentUser == null) {
    initialScreen = WelcomeScreen(dbService: dbService);
  } else {
    initialScreen = MainLayoutScreen(dbService: dbService);
  }

  runApp(MyApp(
    dbService: dbService,
    initialScreen: initialScreen,
  ));
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;
  final Widget initialScreen;

  const MyApp({
    super.key,
    required this.dbService,
    required this.initialScreen,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TriggerLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.nunitoTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.primaryDark),
          titleTextStyle: GoogleFonts.nunito(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
      ),
      home: initialScreen,
    );
  }
}

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    // NEW: Detects if the software keyboard is currently visible on the screen
    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final List<Widget> screens = [
      DashboardScreen(dbService: widget.dbService),
      DigitalPantryScreen(dbService: widget.dbService),
      InsightsScreen(dbService: widget.dbService),
      CoachScreen(dbService: widget.dbService),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_currentIndex],
      // Hide the floating action button when the keyboard is open
      floatingActionButton: isKeyboardOpen
          ? null
          : Container(
              width: 75,
              height: 75,
              margin: const EdgeInsets.only(top: 35),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: FloatingActionButton(
                elevation: 0,
                backgroundColor: Colors.transparent,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ScannerScreen(dbService: widget.dbService),
                  ),
                ),
                child:
                    Image.asset('assets/images/barcode-scanner.png', width: 40),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Hide the bottom navigation bar when the keyboard is open
      bottomNavigationBar: isKeyboardOpen
          ? null
          : Container(
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
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
                      _buildNavItem('assets/images/home.png', 0),
                      _buildNavItem('assets/images/write.png', 1),
                      const SizedBox(width: 45),
                      _buildNavItem('assets/images/bar-graph.png', 2),
                      _buildNavItem('assets/images/message.png', 3),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem(String imagePath, int index) {
    final isSelected = _currentIndex == index;

    return IconButton(
      icon: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Image.asset(
          imagePath,
          width: 24,
          color: isSelected ? Colors.white : AppColors.textDark,
        ),
      ),
      onPressed: () => setState(() => _currentIndex = index),
    );
  }
}
