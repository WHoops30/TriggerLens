import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import 'sign_up_screen.dart';
import 'path_screen.dart';
import 'password_recovery_screens.dart';
import 'set_google_password_screen.dart'; // NEW IMPORT

class LogInScreen extends StatefulWidget {
  final DatabaseService dbService;
  const LogInScreen({super.key, required this.dbService});

  @override
  State<LogInScreen> createState() => _LogInScreenState();
}

class _LogInScreenState extends State<LogInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool hidePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (mounted) {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PathScreen(dbService: widget.dbService)));
        }
      } on FirebaseAuthException catch (e) {
        String message = 'Invalid email or password.';
        if (e.code == 'user-not-found' ||
            e.code == 'wrong-password' ||
            e.code == 'invalid-credential') {
          message = 'Invalid email or password.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // --- UPDATED GOOGLE SIGN IN INTERCEPTION ---
  Future<void> _signInWithGoogle() async {
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
        // Check if the user already has an email/password credential attached
        bool hasPassword = user.providerData
            .any((provider) => provider.providerId == 'password');

        if (!hasPassword) {
          // INTERCEPT: Force them to set an app password
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    SetGooglePasswordScreen(dbService: widget.dbService)),
            (route) => false,
          );
        } else {
          // NORMAL FLOW: Proceed to dashboard
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PathScreen(dbService: widget.dbService)));
        }
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sign in with Google: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const TriggerLensLogo(
                      size: 70, showText: true, isHorizontal: true),
                  const SizedBox(height: 50),

                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Log In to TriggerLens',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark))),
                  const SizedBox(height: 20),

                  CustomTextField(
                      hint: 'Email Address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) => val == null || !val.contains('@')
                          ? 'Invalid email'
                          : null),
                  CustomTextField(
                      hint: 'Password',
                      isPassword: true,
                      hidePassword: hidePassword,
                      controller: _passwordController,
                      onEyeTap: () =>
                          setState(() => hidePassword = !hidePassword),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Required' : null),

                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ForgotPasswordScreen(
                                    dbService: widget.dbService))),
                        child: const Text('Forgot Password?',
                            style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline))),
                  ),

                  const SizedBox(height: 10),

                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : GradientButton(text: 'Log In', onPressed: _login),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: AppColors.primary.withOpacity(0.3),
                                thickness: 1)),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text('or',
                                style: TextStyle(
                                    color: AppColors.primary, fontSize: 12))),
                        Expanded(
                            child: Divider(
                                color: AppColors.primary.withOpacity(0.3),
                                thickness: 1)),
                      ],
                    ),
                  ),

                  // Google Sign In Button
                  InkWell(
                      onTap: _signInWithGoogle,
                      child: const IgnorePointer(
                          child: SocialButton(
                              text: 'Continue with Google',
                              iconColor: Colors.redAccent,
                              textIcon: 'G'))),

                  const SizedBox(height: 30),

                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textDark),
                      children: [
                        const TextSpan(text: 'New to TriggerLens? '),
                        TextSpan(
                          text: 'Sign Up',
                          style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => SignUpScreen(
                                        dbService: widget.dbService))),
                        ),
                      ],
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
