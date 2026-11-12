import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import '../../utils/app_localizations.dart';
import '../../main.dart';
import 'onboarding_screen.dart';

class SetGooglePasswordScreen extends StatefulWidget {
  final DatabaseService dbService;
  const SetGooglePasswordScreen({super.key, required this.dbService});

  @override
  State<SetGooglePasswordScreen> createState() =>
      _SetGooglePasswordScreenState();
}

class _SetGooglePasswordScreenState extends State<SetGooglePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _hidePassword = true;
  bool _hideConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _savePasswordAndRoute() async {
    final loc = AppLocalizations.of(context);

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // 1. Securely link the new password to the Google-authenticated account
          final AuthCredential credential = EmailAuthProvider.credential(
              email: user.email!, password: _passwordController.text.trim());

          try {
            await user.linkWithCredential(credential);
          } catch (e) {
            // If linking fails (e.g. account already has an email provider), fallback to updating
            await user.updatePassword(_passwordController.text.trim());
          }

          // 2. Check the Database Firewall
          final profile = await widget.dbService.getUserProfile();

          if (mounted) {
            if (profile != null && profile.isSetupComplete) {
              // FIXED: Destructive route to Dashboard if already fully calibrated
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        MainLayoutScreen(dbService: widget.dbService)),
                (route) => false,
              );
            } else {
              // FIXED: Destructive route to Smart Onboarding if baseline is missing
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
            SnackBar(
              content: Text(loc.loc('update_failed') != 'update_failed'
                  ? loc.loc('update_failed')
                  : e.toString()),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TriggerLensLogo(size: 60, showText: false),
                  const SizedBox(height: 30),
                  Text(
                    "Secure Your Account",
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: colors.textDark),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "You signed in with Google. Please set a secure backup password for your TriggerLens account to proceed.",
                    style: TextStyle(
                        fontSize: 14, color: colors.textGrey, height: 1.4),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    loc.loc('password'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textDark),
                  ),
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
                  Text(
                    loc.loc('confirm_password'),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colors.textDark),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    hint: loc.loc('confirm_password'),
                    isPassword: true,
                    hidePassword: _hideConfirm,
                    controller: _confirmController,
                    onEyeTap: () =>
                        setState(() => _hideConfirm = !_hideConfirm),
                    validator: (val) => val != _passwordController.text
                        ? loc.loc('mismatch')
                        : null,
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? Center(
                          child:
                              CircularProgressIndicator(color: colors.primary))
                      : GradientButton(
                          text: "Save & Continue",
                          onPressed: _savePasswordAndRoute,
                        ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
