import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/database_service.dart';
import '../../utils/ui_helpers.dart';
import 'log_in_screen.dart';
import 'path_screen.dart';
import 'set_google_password_screen.dart'; // NEW IMPORT

class SignUpScreen extends StatefulWidget {
  final DatabaseService dbService;
  const SignUpScreen({super.key, required this.dbService});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool isChecked = false;
  bool hidePassword = true;
  bool hideConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (!isChecked) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('You must agree to the Data Privacy Policy.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (mounted) {
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PathScreen(dbService: widget.dbService)));
        }
      } on FirebaseAuthException catch (e) {
        String message = e.message ?? 'An error occurred. Please try again.';
        if (e.code == 'weak-password') {
          message = 'The password provided is too weak.';
        } else if (e.code == 'email-already-in-use') {
          message = 'An account already exists for that email.';
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(e.toString()),
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  const TriggerLensLogo(
                      size: 70, showText: true, isHorizontal: true),
                  const SizedBox(height: 30),

                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Create Your Account',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark))),
                  const SizedBox(height: 20),

                  CustomTextField(
                      hint: 'Full Name',
                      controller: _nameController,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Required'
                          : null),
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
                          val != null && val.length < 6 ? 'Min 6 chars' : null),
                  CustomTextField(
                      hint: 'Confirm Password',
                      isPassword: true,
                      hidePassword: hideConfirm,
                      controller: _confirmPasswordController,
                      onEyeTap: () =>
                          setState(() => hideConfirm = !hideConfirm),
                      validator: (val) =>
                          val != _passwordController.text ? 'Mismatch' : null),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                              value: isChecked,
                              activeColor: AppColors.primary,
                              onChanged: (val) =>
                                  setState(() => isChecked = val ?? false))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                                fontSize: 9,
                                color: AppColors.textDark,
                                height: 1.3),
                            children: [
                              const TextSpan(
                                  text: 'I have read and understood the '),
                              const TextSpan(
                                  text: 'Data Privacy Policy',
                                  style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold)),
                              const TextSpan(
                                  text:
                                      ' and consent to the processing of my data in accordance with the DPA of 2012. '),
                              TextSpan(
                                  text: 'Learn More',
                                  style: const TextStyle(
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.bold),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {}),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : GradientButton(text: 'Sign Up', onPressed: _submitForm),

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
                            textIcon: 'G')),
                  ),

                  const SizedBox(height: 20),

                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textDark),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log In',
                          style: const TextStyle(
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => LogInScreen(
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
