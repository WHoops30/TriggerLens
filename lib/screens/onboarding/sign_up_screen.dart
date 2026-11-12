import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_localizations.dart';
import '../../main.dart';
import 'log_in_screen.dart';
import 'privacy_screen.dart';
import 'set_google_password_screen.dart';
import 'onboarding_screen.dart';
import 'package:flutter/services.dart';

class SignUpScreen extends StatefulWidget {
  final DatabaseService dbService;
  const SignUpScreen({super.key, required this.dbService});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _hidePassword1 = true;
  bool _hidePassword2 = true;
  bool _agreedToPrivacy = false;

  // Real-time Password Strength State
  double _passwordStrength = 0.0;
  String _strengthLabel = "";
  Color _strengthColor = Colors.grey;
  bool _meetsCriteria = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // ==========================================
  // REAL-TIME PASSWORD SECURITY VALIDATOR
  // ==========================================
  void _checkPasswordStrength() {
    String pass = _passwordController.text;

    bool hasMinLength = pass.length >= 8;
    bool hasUpper = pass.contains(RegExp(r'[A-Z]'));
    bool hasLower = pass.contains(RegExp(r'[a-z]'));
    bool hasNumber = pass.contains(RegExp(r'[0-9]'));
    bool hasSpecial = pass.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));

    int passedCriteria = 0;
    if (hasMinLength) passedCriteria++;
    if (hasUpper) passedCriteria++;
    if (hasLower) passedCriteria++;
    if (hasNumber) passedCriteria++;
    if (hasSpecial) passedCriteria++;

    setState(() {
      if (pass.isEmpty) {
        _passwordStrength = 0.0;
        _strengthLabel = "";
        _strengthColor = Colors.grey;
        _meetsCriteria = false;
      } else if (passedCriteria <= 2) {
        _passwordStrength = 0.33;
        _strengthLabel = "Weak";
        _strengthColor = Colors.redAccent;
        _meetsCriteria = false;
      } else if (passedCriteria <= 4) {
        _passwordStrength = 0.66;
        _strengthLabel = "Fair";
        _strengthColor = Colors.orangeAccent;
        _meetsCriteria = false;
      } else {
        _passwordStrength = 1.0;
        _strengthLabel = "Strong";
        _strengthColor = Colors.green;
        _meetsCriteria = true;
      }
    });
  }

  void _showVerificationDialog(AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.mark_email_unread_rounded,
                color: colors.primary, size: 50),
            const SizedBox(height: 15),
            Text(
              loc.loc('Verify Your Email'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: colors.primaryDark),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          loc.loc(
              'We have sent a verification link to your email. Please verify your account before logging in to access your medical dashboard.'),
          style: TextStyle(color: colors.textDark, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          LogInScreen(dbService: widget.dbService)),
                  (route) => false,
                );
              },
              child: Text(loc.loc('log_in_btn'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _signUp(AppColors colors, AppLocalizations loc) async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Strict Privacy Policy Check
    if (!_agreedToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.loc('agree_to_privacy')),
          backgroundColor: colors.errorRed,
        ),
      );
      return;
    }

    // 2. Strict Password Strength Check
    if (!_meetsCriteria) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(loc.loc('Password must meet all security requirements.')),
          backgroundColor: colors.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 3. Create Account
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 4. Update Profile Data
      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      // 5. Fire Email Verification & Lockout
      await userCredential.user?.sendEmailVerification();
      await FirebaseAuth.instance
          .signOut(); // Immediately sign out so they can't bypass verification

      if (mounted) {
        _showVerificationDialog(colors, loc);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? loc.loc('update_failed')),
            backgroundColor: colors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    final loc = AppLocalizations.of(context);
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null && mounted) {
        bool hasPassword = user.providerData
            .any((provider) => provider.providerId == 'password');

        if (!hasPassword) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    SetGooglePasswordScreen(dbService: widget.dbService)),
            (route) => false,
          );
        } else {
          final profile = await widget.dbService.getUserProfile();

          if (profile != null && profile.isSetupComplete) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      MainLayoutScreen(dbService: widget.dbService)),
              (route) => false,
            );
          } else {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      OnboardingScreen(dbService: widget.dbService)),
              (route) => false,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Sign-In Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back_1.png',
              width: 24, color: colors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TriggerLensLogo(size: 60, showText: false),
                  const SizedBox(height: 30),
                  Text(loc.loc('create_your_account'),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: colors.textDark)),
                  const SizedBox(height: 30),
                  Text(loc.loc('full_name'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textDark)),
                  const SizedBox(height: 8),
                  CustomTextField(
                    hint: loc.loc('full_name'),
                    controller: _nameController,
                    validator: (val) => val == null || val.isEmpty
                        ? loc.loc('required_field')
                        : null,
                  ),
                  Text(loc.loc('email_address'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textDark)),
                  const SizedBox(height: 8),
                  CustomTextField(
                    hint: loc.loc('email_address'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || !val.contains('@')
                        ? loc.loc('invalid_email_format')
                        : null,
                  ),
                  Text(loc.loc('password'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textDark)),
                  const SizedBox(height: 8),
                  CustomTextField(
                    hint: loc.loc('password'),
                    isPassword: true,
                    hidePassword: _hidePassword1,
                    controller: _passwordController,
                    onEyeTap: () =>
                        setState(() => _hidePassword1 = !_hidePassword1),
                    validator: (val) => val == null || val.length < 8
                        ? loc.loc('min_8_chars',
                            {'default': 'Minimum 8 characters required'})
                        : null,
                  ),

                  // ==========================================
                  // LIVE PASSWORD STRENGTH UI
                  // ==========================================
                  if (_passwordController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.loc('Password Strength'),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textGrey),
                              ),
                              Text(
                                loc.loc(_strengthLabel),
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: _strengthColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Stack(
                            children: [
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: colors.isDark
                                      ? Colors.white12
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOutCubic,
                                height: 6,
                                width: MediaQuery.of(context).size.width *
                                    0.85 *
                                    _passwordStrength,
                                decoration: BoxDecoration(
                                    color: _strengthColor,
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _strengthColor.withOpacity(0.4),
                                        blurRadius: 4,
                                      )
                                    ]),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            loc.loc(
                                'Must contain at least 8 characters, 1 uppercase, 1 lowercase, 1 number, and 1 special character.'),
                            style: TextStyle(
                                fontSize: 9,
                                height: 1.4,
                                color: _meetsCriteria
                                    ? colors.successGreen
                                    : colors.textGrey),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 5),

                  Text(loc.loc('confirm_password'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.textDark)),
                  const SizedBox(height: 8),
                  CustomTextField(
                    hint: loc.loc('confirm_password'),
                    isPassword: true,
                    hidePassword: _hidePassword2,
                    controller: _confirmController,
                    onEyeTap: () =>
                        setState(() => _hidePassword2 = !_hidePassword2),
                    validator: (val) => val != _passwordController.text
                        ? loc.loc('mismatch')
                        : null,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _agreedToPrivacy,
                        activeColor: colors.primary,
                        onChanged: (val) =>
                            setState(() => _agreedToPrivacy = val ?? false),
                      ),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 10,
                                color: colors.textGrey,
                                height: 1.4),
                            children: [
                              TextSpan(text: loc.loc('read_understood')),
                              TextSpan(
                                text: loc.loc('data_privacy_policy'),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colors.primaryDark),
                              ),
                              TextSpan(text: loc.loc('consent_processing')),
                              TextSpan(
                                text: loc.loc('learn_more'),
                                style: const TextStyle(
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.bold),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () async {
                                    final bool? userAgreed =
                                        await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => PrivacyScreen(
                                              dbService: widget.dbService)),
                                    );

                                    if (userAgreed == true) {
                                      setState(() {
                                        _agreedToPrivacy = true;
                                      });
                                    }
                                  },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _isLoading
                      ? Center(
                          child:
                              CircularProgressIndicator(color: colors.primary))
                      : GradientButton(
                          text: loc.loc('sign_up'),
                          onPressed: () => _signUp(colors, loc),
                        ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: colors.primary.withOpacity(0.3),
                                thickness: 1)),
                        Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(loc.loc('or'),
                                style: TextStyle(
                                    color: colors.primary, fontSize: 12))),
                        Expanded(
                            child: Divider(
                                color: colors.primary.withOpacity(0.3),
                                thickness: 1)),
                      ],
                    ),
                  ),
                  SocialButton(
                    text: loc.loc('continue_google'),
                    iconColor: Colors.redAccent,
                    textIcon: 'G',
                    onPressed: _signInWithGoogle,
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  LogInScreen(dbService: widget.dbService))),
                      child: RichText(
                        text: TextSpan(
                          style:
                              TextStyle(color: colors.textGrey, fontSize: 13),
                          children: [
                            TextSpan(
                                text: loc.loc('already_have_account_login')),
                            TextSpan(
                                text: loc.loc('log_in_btn'),
                                style: TextStyle(
                                    color: colors.primary,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
