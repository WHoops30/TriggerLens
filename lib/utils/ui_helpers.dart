import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryDark = Color(0xFF4A1A8C);
  static const Color primary = Color(0xFF7B3FB9);
  static const Color primaryLight = Color(0xFFB57EDC);
  static const Color accentOrange = Color(0xFFFFA726);
  static const Color accentCyan = Color(0xFF4DD0E1);
  static const Color background = Color(0xFFF9F9F9);
  static const Color textDark = Color(0xFF2D2D2D);
  static const Color textGrey = Color(0xFF8E8E8E);
  static const Color errorRed = Color(0xFFE53935);
  static const Color successGreen = Color(0xFF43A047);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryLight, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFEBE2F5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// -------------------------------------------------------------
// REUSABLE LOGO
// -------------------------------------------------------------
class TriggerLensLogo extends StatelessWidget {
  final double size;
  final bool isHorizontal;
  final bool showText;

  const TriggerLensLogo({
    super.key,
    this.size = 110,
    this.isHorizontal = false,
    this.showText = true, // Added missing parameter
  });

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/images/triggerlens_icon.png',
      width: size,
      fit: BoxFit.contain,
    );

    // If showText is false, just return the image alone
    if (!showText) {
      return image;
    }

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('TRIGGER',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                  letterSpacing: 1.0)),
          const Text('LENS',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w400,
                  color: AppColors.primaryDark,
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
          children: const [
            Text('TRIGGER',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    letterSpacing: 1.5)),
            Text('LENS',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: AppColors.primaryDark,
                    letterSpacing: 1.5)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'An OCR-Driven Ingredient Analyzer\nFor Powdered Drink Sachets for Acid Reflux Management',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              color: AppColors.textGrey,
              height: 1.5,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// REUSABLE BUTTONS
// -------------------------------------------------------------
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;

  const GradientButton(
      {super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 55,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : AppColors.primaryGradient,
        color: onPressed == null ? Colors.grey.shade300 : null,
        borderRadius: BorderRadius.circular(30),
        boxShadow: onPressed == null
            ? []
            : [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
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
  final Color iconColor; // Added missing parameter
  final IconData? icon; // Added missing parameter
  final String? textIcon; // Added missing parameter

  const SocialButton(
      {super.key,
      required this.text,
      required this.iconColor,
      this.icon,
      this.textIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      height: 55,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        onPressed: () {},
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
            Text(text,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.textDark)),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// REUSABLE TEXT FIELD
// -------------------------------------------------------------
class CustomTextField extends StatelessWidget {
  final String hint;
  final bool isPassword;
  final bool hidePassword;
  final VoidCallback? onEyeTap;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.hint,
    this.isPassword = false,
    this.hidePassword = false,
    this.onEyeTap,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: isPassword && hidePassword,
        style: const TextStyle(
            color: AppColors.textDark, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: AppColors.textGrey.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.primaryLight, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide:
                const BorderSide(color: AppColors.primaryDark, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: const BorderSide(color: AppColors.errorRed, width: 2.0),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Image.asset('assets/images/hide.png',
                      width: 20,
                      color: hidePassword
                          ? AppColors.textGrey
                          : AppColors.primaryDark),
                  onPressed: onEyeTap,
                )
              : null,
        ),
      ),
    );
  }
}
