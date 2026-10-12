import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ADDED: For persistent login check
import 'firebase_options.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/database_service.dart';
import 'screens/scanner_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/onboarding/path_screen.dart'; // ADDED: To route logged-in users
import 'utils/ui_helpers.dart';
import 'screens/digital_pantry_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/coach_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(MyApp(dbService: dbService));
}

class MyApp extends StatelessWidget {
  final DatabaseService dbService;
  const MyApp({super.key, required this.dbService});

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
      // THE SMART DOOR: Checks if a Firebase session exists before showing the Welcome Screen
      home: FirebaseAuth.instance.currentUser == null
          ? WelcomeScreen(dbService: dbService)
          : PathScreen(dbService: dbService),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  final DatabaseService dbService;
  final int initialIndex;

  const MainLayoutScreen(
      {super.key, required this.dbService, this.initialIndex = 0});

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
    final List<Widget> screens = [
      DashboardScreen(dbService: widget.dbService),
      DigitalPantryScreen(dbService: widget.dbService),
      InsightsScreen(dbService: widget.dbService),
      CoachScreen(dbService: widget.dbService),
    ];

    return Scaffold(
      extendBody: true,
      body: screens[_currentIndex],
      floatingActionButton: Container(
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
                offset: const Offset(0, 8))
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ScannerScreen(dbService: widget.dbService))),
          child: Image.asset('assets/images/barcode-scanner.png', width: 40),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 5))
            ]),
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
                const SizedBox(width: 45), // Space for FAB
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
            borderRadius: BorderRadius.circular(15)),
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
