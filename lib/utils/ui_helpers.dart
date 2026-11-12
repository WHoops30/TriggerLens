import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ==========================================
// 1. STATE MANAGER: Account-Isolated Dynamic Theming
// ==========================================
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Color _seedColor = const Color(0xFF7B3FB9);

  static const List<Color> availableThemes = [
    Color(0xFF7B3FB9), // 0: Default Purple
    Colors.orange, // 1: Orange
    Colors.lightBlue, // 2: Light Blue
    Colors.pink, // 3: Pink
    Colors.green, // 4: Green
    Colors.red, // 5: Red
    Colors.teal, // 6: Teal
    Colors.indigo, // 7: Indigo
    Colors.amber, // 8: Amber
    Colors.deepOrange, // 9: Deep Orange
  ];

  ThemeMode get themeMode => _themeMode;
  Color get seedColor => _seedColor;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    int? themeIndex = prefs.getInt('theme_mode_$_uid');
    if (themeIndex != null) {
      _themeMode = ThemeMode.values[themeIndex];
    } else {
      _themeMode = ThemeMode.light;
    }

    int? colorValue = prefs.getInt('seed_color_$_uid');
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    } else {
      _seedColor = const Color(0xFF7B3FB9);
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode_$_uid', mode.index);
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    _seedColor = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seed_color_$_uid', color.value);
    notifyListeners();
  }

  ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: baseScheme.copyWith(
        surface: const Color(0xFFF9F9F9),
        surfaceTint: Colors.transparent,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      scaffoldBackgroundColor: const Color(0xFFF9F9F9),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          color: const Color(0xFF2D2D2D),
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    );
  }

  ThemeData get darkTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: baseScheme.copyWith(
        surface: const Color(0xFF121212),
        surfaceTint: Colors.transparent,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      ),
    );
  }
}

// ==========================================
// 2. CONTEXTUAL COLOR WRAPPER
// ==========================================
class AppColors {
  final ColorScheme _scheme;
  final Brightness _brightness;

  AppColors(this._scheme, this._brightness);

  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return AppColors(theme.colorScheme, theme.brightness);
  }

  bool get isDark => _brightness == Brightness.dark;

  Color get primaryDark => isDark ? _scheme.primaryContainer : _scheme.primary;
  Color get primary => _scheme.primary;
  Color get primaryLight => _scheme.secondaryContainer;
  Color get accentOrange => Colors.orange;
  Color get accentCyan => Colors.cyan;

  Color get background =>
      isDark ? const Color(0xFF121212) : const Color(0xFFF9F9F9);
  Color get cardColor => isDark ? const Color(0xFF1E1E1E) : Colors.white;

  Color get textDark => _scheme.onSurface;
  Color get textGrey => _scheme.onSurfaceVariant;
  Color get errorRed => _scheme.error;
  Color get successGreen => const Color(0xFF43A047);

  // FIXED: Converted gradient to a solid block for a premium, non-muddy aesthetic
  LinearGradient get primaryGradient => LinearGradient(
        colors: [primary, primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

// ==========================================
// 3. ADAPTIVE REUSABLE WIDGETS
// ==========================================
class TriggerLensLogo extends StatelessWidget {
  final double size;
  final bool isHorizontal;
  final bool showText;

  const TriggerLensLogo({
    super.key,
    this.size = 110,
    this.isHorizontal = false,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    Widget image = Image.asset(
      'assets/images/triggerlens_icon.png',
      width: size,
      fit: BoxFit.contain,
    );

    if (!showText) return image;

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('TRIGGER',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: colors.primaryDark,
                  letterSpacing: 1.0)),
          Text('LENS',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: colors.primaryDark,
                  letterSpacing: 1.0)),
          const SizedBox(width: 10),
          image,
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        image,
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('TRIGGER',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: colors.primaryDark,
                    letterSpacing: 1.5)),
            Text('LENS',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: colors.primaryDark,
                    letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'An OCR-Driven Ingredient Analyzer\nFor Powdered Drink Sachets for Acid Reflux Management',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              color: colors.textGrey,
              height: 1.5,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// FIXED: Solid Premium Color with soft drop-shadow
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const GradientButton(
      {super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        color: onPressed == null
            ? (colors.isDark ? Colors.white12 : Colors.grey.shade300)
            : colors.primary,
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                    color: colors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5))
              ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: onPressed,
        child: Text(text,
            style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  final String text;
  final Color iconColor;
  final IconData? icon;
  final String? textIcon;
  final VoidCallback onPressed;

  const SocialButton(
      {super.key,
      required this.text,
      required this.iconColor,
      required this.onPressed,
      this.icon,
      this.textIcon});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      height: 55,
      width: double.infinity,
      decoration: BoxDecoration(boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4))
      ]),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.cardColor,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(icon, color: iconColor, size: 24)
            else if (textIcon != null)
              Text(textIcon!,
                  style: TextStyle(
                      color: iconColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: colors.textDark)),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomTextField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool isPassword;
  final bool hidePassword;
  final VoidCallback? onEyeTap;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;

  const CustomTextField({
    super.key,
    required this.hint,
    required this.controller,
    this.isPassword = false,
    this.hidePassword = false,
    this.onEyeTap,
    this.validator,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? hidePassword : false,
        keyboardType: keyboardType,
        style: TextStyle(color: colors.textDark, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(color: colors.textGrey, fontWeight: FontWeight.normal),
          filled: true,
          fillColor: colors.background,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
                color: colors.isDark ? Colors.white12 : Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
                color: colors.isDark ? Colors.white12 : Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: colors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: colors.errorRed, width: 2),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    hidePassword ? Icons.visibility_off : Icons.visibility,
                    color: colors.textGrey,
                  ),
                  onPressed: onEyeTap,
                )
              : null,
        ),
        validator: validator,
      ),
    );
  }
}

// FIXED: InfoTooltip for Cognitive Easing and Progressive Disclosure
class InfoTooltip extends StatelessWidget {
  final String message;
  final Color? iconColor;

  const InfoTooltip({super.key, required this.message, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Tooltip(
      message: message,
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: colors.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.primary),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
        ],
      ),
      textStyle: TextStyle(
          color: colors.textDark,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          height: 1.4),
      child: Icon(Icons.info_outline,
          color: iconColor ?? colors.primary, size: 18),
    );
  }
}
