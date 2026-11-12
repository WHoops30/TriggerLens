import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_localizations.dart';
import '../../main.dart';
import 'sign_up_screen.dart';
import 'set_google_password_screen.dart';
import 'onboarding_screen.dart';

class LogInScreen extends StatefulWidget {
  final DatabaseService dbService;
  const LogInScreen({super.key, required this.dbService});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==========================================
  // UNVERIFIED EMAIL FALLBACK UI
  // ==========================================
  void _showUnverifiedDialog(
      User user, AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Icon(Icons.mark_email_unread_rounded,
                color: colors.errorRed, size: 50),
            const SizedBox(height: 15),
            Text(
              loc.loc('Email Not Verified'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: colors.errorRed),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          loc.loc(
              'You must verify your email address before you can securely access your medical dashboard. Please check your inbox.'),
          style: TextStyle(color: colors.textDark, height: 1.5),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.loc('cancel'),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              try {
                await user.sendEmailVerification();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.loc(
                          'Verification email sent to {email}',
                          {'email': user.email ?? ''})),
                      backgroundColor: colors.successGreen,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(loc.loc('error_msg', {'message': e.toString()})),
                      backgroundColor: colors.errorRed,
                    ),
                  );
                }
              }
            },
            child: Text(loc.loc('Resend Link'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _logIn(AppColors colors, AppLocalizations loc) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = userCredential.user;

      if (user != null) {
        // ENFORCER: Block entry if the email isn't verified yet
        if (!user.emailVerified) {
          await FirebaseAuth.instance
              .signOut(); // Terminate session immediately
          if (mounted) {
            setState(() => _isLoading = false);
            _showUnverifiedDialog(user, colors, loc);
          }
          return;
        }

        final profile = await widget.dbService.getUserProfile();

        if (mounted) {
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
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? loc.loc('invalid_email_pass')),
            backgroundColor: colors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
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

  void _resetPassword(AppColors colors, AppLocalizations loc) {
    showDialog(
      context: context,
      builder: (context) {
        final resetEmailController = TextEditingController();
        return AlertDialog(
          backgroundColor: colors.cardColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.loc('forgot_password_title'),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colors.primaryDark)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.loc('forgot_password_desc'),
                  style: TextStyle(color: colors.textDark)),
              const SizedBox(height: 15),
              CustomTextField(
                hint: loc.loc('email_address'),
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.loc('cancel'),
                    style: const TextStyle(color: Colors.grey))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isNotEmpty && email.contains('@')) {
                  Navigator.pop(context);
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: email);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              loc.loc('reset_link_sent', {'email': email})),
                          backgroundColor: colors.successGreen));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text("${loc.loc('error_msg')}: ${e.toString()}"),
                          backgroundColor: colors.errorRed));
                    }
                  }
                }
              },
              child: Text(loc.loc('send_email'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
                  Text(loc.loc('log_in_title'),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: colors.textDark)),
                  const SizedBox(height: 30),
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
                    hidePassword: _hidePassword,
                    controller: _passwordController,
                    onEyeTap: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    validator: (val) => val == null || val.length < 6
                        ? loc.loc('min_6_chars')
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _resetPassword(colors, loc),
                      child: Text(loc.loc('forgot_password'),
                          style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _isLoading
                      ? Center(
                          child:
                              CircularProgressIndicator(color: colors.primary))
                      : GradientButton(
                          text: loc.loc('log_in_btn'),
                          onPressed: () => _logIn(colors, loc),
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
                                  SignUpScreen(dbService: widget.dbService))),
                      child: RichText(
                        text: TextSpan(
                          style:
                              TextStyle(color: colors.textGrey, fontSize: 13),
                          children: [
                            TextSpan(text: loc.loc('new_to_triggerlens') + ' '),
                            TextSpan(
                                text: loc.loc('sign_up_link'),
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
